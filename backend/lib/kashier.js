import crypto from "crypto";

const apiBase = () => (process.env.KASHIER_MODE === "live" ? "https://api.kashier.io" : "https://test-api.kashier.io");

const sign = (str) => crypto.createHmac("sha256", process.env.KASHIER_API_KEY).update(str).digest("hex");
const safeEqual = (a, b) => {
	const x = Buffer.from(String(a || "").toLowerCase()), y = Buffer.from(String(b || "").toLowerCase());
	return x.length === y.length && crypto.timingSafeEqual(x, y);
};
const enc = (v) => encodeURIComponent(v).replace(/[!'()*]/g, (c) => `%${c.charCodeAt(0).toString(16).toUpperCase()}`);

// Webhook: sort data.signatureKeys, join key=encoded(value), HMAC-SHA256 with the Payment API Key.
export const verifyWebhookSignature = (data, signature) => {
	if (!data || !Array.isArray(data.signatureKeys)) return false;
	const payload = [...data.signatureKeys]
		.sort()
		.filter((k) => data[k] !== undefined)
		.map((k) => (data[k] === null ? enc(k) : `${enc(k)}=${enc(data[k])}`))
		.join("&");
	return safeEqual(sign(payload), signature);
};

// Redirect: fixed field order, missing fields are the literal "null"; signature and mode are excluded.
const REDIRECT_FIELDS = ["paymentStatus", "cardDataToken", "maskedCard", "merchantOrderId", "orderId", "cardBrand", "orderReference", "transactionId", "amount", "currency"];
export const verifyRedirectSignature = (params) => {
	const body = REDIRECT_FIELDS.map((f) => `${f}=${params[f] ?? "null"}`).join("&");
	return safeEqual(sign(body), params.signature);
};

export const createSession = async ({ reference, amount, email, customerRef, redirectUrl, webhookUrl }) => {
	const res = await fetch(`${apiBase()}/v3/payment/sessions`, {
		method: "POST",
		headers: {
			Authorization: process.env.KASHIER_SECRET_KEY,
			"api-key": process.env.KASHIER_API_KEY,
			"Content-Type": "application/json",
		},
		body: JSON.stringify({
			expireAt: new Date(Date.now() + 60 * 60 * 1000).toISOString(),
			maxFailureAttempts: 3,
			paymentType: "credit",
			amount: amount.toFixed(2),
			currency: process.env.KASHIER_CURRENCY || "EGP",
			order: reference,
			merchantId: process.env.KASHIER_MERCHANT_ID,
			merchantRedirect: redirectUrl,
			display: "en",
			type: "one-time",
			allowedMethods: "card,wallet",
			failureRedirect: false,
			description: `Order ${reference.slice(0, 8)}`,
			customer: { email, reference: customerRef },
			...(webhookUrl ? { serverWebhook: webhookUrl } : {}),
		}),
	});
	if (!res.ok) throw new Error(`Kashier session failed: ${res.status} ${await res.text()}`);
	return res.json(); // { _id, sessionUrl, ... }
};
