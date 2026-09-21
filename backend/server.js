import "dotenv/config"; // must stay first, so env vars exist before other files read them
import express from "express";
import cookieParser from "cookie-parser";
import path from "path";
import mongoose from "mongoose";

import authRoutes from "./routes/auth.route.js";
import productRoutes from "./routes/product.route.js";
import cartRoutes from "./routes/cart.route.js";
import couponRoutes from "./routes/coupon.route.js";
import paymentRoutes from "./routes/payment.route.js";
import analyticsRoutes from "./routes/analytics.route.js";
import healthRoutes from "./routes/health.route.js";

import { connectDB } from "./lib/db.js";
import { connectRedis, redis } from "./lib/redis.js";

const app = express();
const PORT = process.env.PORT || 5000;

const __dirname = path.resolve();

app.use(express.json({ limit: "10mb" })); // allows you to parse the body of the request
app.use(cookieParser());

app.use("/api/auth", authRoutes);
app.use("/api/products", productRoutes);
app.use("/api/cart", cartRoutes);
app.use("/api/coupons", couponRoutes);
app.use("/api/payments", paymentRoutes);
app.use("/api/analytics", analyticsRoutes);
app.use("/api/health", healthRoutes);

if (process.env.NODE_ENV === "production") {
	app.use(express.static(path.join(__dirname, "/frontend/dist")));

	app.get("*", (req, res) => {
		res.sendFile(path.resolve(__dirname, "frontend", "dist", "index.html"));
	});
}

const start = async () => {
	try {
		await connectDB();
		await connectRedis();
	} catch (err) {
		console.error("Startup failed, exiting:", err.message);
		process.exit(1);
	}

	const server = app.listen(PORT, () => {
		console.log("Server is running on http://localhost:" + PORT);
	});

	// clean shutdown when the instance is stopped (scale-in, CodeDeploy)
	const shutdown = (signal) => {
		console.log(`${signal} received, shutting down`);
		server.close(async () => {
			await mongoose.connection.close().catch(() => {});
			await redis.quit().catch(() => {});
			process.exit(0);
		});
		setTimeout(() => process.exit(1), 10000).unref(); // force exit after 10s
	};
	process.on("SIGTERM", () => shutdown("SIGTERM"));
	process.on("SIGINT", () => shutdown("SIGINT"));
};

start();
