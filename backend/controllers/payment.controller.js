import Coupon from "../models/coupon.model.js";
import crypto from "crypto";
import Order from "../models/order.model.js";
import Checkout from "../models/checkout.model.js";
import { createSession, verifyRedirectSignature, verifyWebhookSignature } from "../lib/kashier.js";

export const createCheckoutSession = async (req, res) => {
	try {
		const { products, couponCode } = req.body;

		if (!Array.isArray(products) || products.length === 0) {
			return res.status(400).json({ error: "Invalid or empty products array" });
		}

		let totalCents = products.reduce(
			(sum, p) => sum + Math.round(p.price * 100) * (p.quantity || 1),
			0
		);

		let coupon = null;
		if (couponCode) {
			coupon = await Coupon.findOne({ code: couponCode, userId: req.user._id, isActive: true });
			if (coupon) totalCents -= Math.round((totalCents * coupon.discountPercentage) / 100);
		}

		const reference = crypto.randomUUID();
		await Checkout.create({
			reference,
			user: req.user._id,
			products: products.map((p) => ({ product: p._id, quantity: p.quantity || 1, price: p.price })),
			couponCode: coupon ? coupon.code : null,
			totalAmount: totalCents / 100,
		});

		// Kashier calls the webhook from the internet, so skip it for localhost
		const isLocal = /localhost|127\.0\.0\.1/.test(process.env.CLIENT_URL);
		const session = await createSession({
			reference,
			amount: totalCents / 100,
			email: req.user.email,
			customerRef: req.user._id.toString(),
			redirectUrl: `${process.env.CLIENT_URL}/purchase-success`,
			webhookUrl: isLocal ? null : `${process.env.CLIENT_URL}/api/payments/kashier-webhook`,
		});

		await Checkout.updateOne({ reference }, { kashierSessionId: session._id });
		res.status(200).json({ checkoutUrl: session.sessionUrl, totalAmount: totalCents / 100 });
	} catch (error) {
		console.error("Error processing checkout:", error);
		res.status(500).json({ message: "Error processing checkout", error: error.message });
	}
};

// Idempotent: the unique kashierReference makes webhook + redirect safe to race.
async function finalizeCheckout(checkout, { transactionId, amount }) {
	if (Math.round(checkout.totalAmount * 100) !== Math.round(Number(amount) * 100)) {
		throw new Error(`Amount mismatch for ${checkout.reference}`);
	}

	let order;
	try {
		order = await Order.create({
			user: checkout.user,
			products: checkout.products.map((p) => ({ product: p.product, quantity: p.quantity, price: p.price })),
			totalAmount: checkout.totalAmount,
			kashierReference: checkout.reference,
			kashierTransactionId: String(transactionId),
		});
	} catch (err) {
		if (err.code === 11000) return Order.findOne({ kashierReference: checkout.reference });
		throw err;
	}

	if (checkout.couponCode) {
		await Coupon.findOneAndUpdate({ code: checkout.couponCode, userId: checkout.user }, { isActive: false });
	}
	if (checkout.totalAmount >= 200) await createNewCoupon(checkout.user);

	return order;
}

export const checkoutSuccess = async (req, res) => {
	try {
		const { params } = req.body;
		if (!params || !verifyRedirectSignature(params)) {
			return res.status(400).json({ message: "Invalid payment signature" });
		}
		if (params.paymentStatus !== "SUCCESS") {
			return res.status(402).json({ message: "Payment not completed" });
		}

		const checkout = await Checkout.findOne({ reference: params.merchantOrderId });
		if (!checkout || String(checkout.user) !== String(req.user._id)) {
			return res.status(404).json({ message: "Checkout not found" });
		}

		const order = await finalizeCheckout(checkout, { transactionId: params.transactionId, amount: params.amount });
		res.status(200).json({ success: true, message: "Payment successful, order created.", orderId: order._id });
	} catch (error) {
		console.error("Error processing successful checkout:", error);
		res.status(500).json({ message: "Error processing successful checkout", error: error.message });
	}
};

export const kashierWebhook = async (req, res) => {
	try {
		const { event, data } = req.body || {};
		if (!data || !verifyWebhookSignature(data, req.header("x-kashier-signature"))) {
			return res.sendStatus(401);
		}
		if (event === "pay" && data.status === "SUCCESS") {
			const checkout = await Checkout.findOne({ reference: data.merchantOrderId });
			if (checkout) await finalizeCheckout(checkout, { transactionId: data.transactionId, amount: data.amount });
			else console.warn("Kashier webhook: no checkout for", data.merchantOrderId);
		}
		res.sendStatus(200);
	} catch (error) {
		console.error("Kashier webhook error:", error);
		res.sendStatus(500); // non-2xx makes Kashier retry
	}
};
