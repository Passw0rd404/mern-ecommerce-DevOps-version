import mongoose from "mongoose";

const checkoutSchema = new mongoose.Schema({
	reference: { type: String, required: true, unique: true },
	user: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
	products: [{ product: mongoose.Schema.Types.ObjectId, quantity: Number, price: Number }],
	couponCode: { type: String, default: null },
	totalAmount: { type: Number, required: true },
  kashierSessionId: String,
	createdAt: { type: Date, default: Date.now, expires: 60 * 60 * 24 * 7 },
});

export default mongoose.model("Checkout", checkoutSchema);
