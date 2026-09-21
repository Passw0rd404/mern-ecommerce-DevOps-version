import express from "express";
import mongoose from "mongoose";
import { isRedisHealthy } from "../lib/redis.js";

const router = express.Router();

// GET /api/health  -> "is the process alive?" (use this for the ALB, same as now)
router.get("/", (req, res) => {
	res.status(200).json({ status: "ok" });
});

// GET /api/health/ready  -> "are Mongo and Redis working?" (for debugging/checks)
router.get("/ready", async (req, res) => {
	const mongo = mongoose.connection.readyState === 1;
	const redisOk = await isRedisHealthy();
	const ready = mongo && redisOk;
	res.status(ready ? 200 : 503).json({
		status: ready ? "ready" : "not_ready",
		mongo,
		redis: redisOk,
	});
});

export default router;
