import mongoose from "mongoose";

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

export const connectDB = async (maxAttempts = 5) => {
	for (let attempt = 1; attempt <= maxAttempts; attempt++) {
		try {
			const conn = await mongoose.connect(process.env.MONGO_URI, {
				serverSelectionTimeoutMS: 10000,
				maxPoolSize: 20,
			});
			console.log(`MongoDB connected: ${conn.connection.host}`);
			return conn;
		} catch (error) {
			console.error(`MongoDB attempt ${attempt}/${maxAttempts} failed:`, error.message);
			if (attempt === maxAttempts) throw error;
			await sleep(attempt * 2000);
		}
	}
};
