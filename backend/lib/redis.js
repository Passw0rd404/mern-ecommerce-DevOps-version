import Redis from "ioredis";
import dotenv from "dotenv";

dotenv.config();

export const redis = new Redis({
  host: process.env.REDIS_HOST,
  port: process.env.REDIS_PORT || 6379,
  password: process.env.REDIS_PASSWORD || undefined,

  // TLS always on when password is set (ElastiCache requires it)
  tls: process.env.REDIS_TLS === "true" ? {
    rejectUnauthorized: true,   // verify AWS certificate
  } : undefined,

  retryStrategy(times) {
    if (times > 3) {
      console.error("Redis failed after 3 retries");
      return null;             // stop retrying instead of infinite loop
    }
    return Math.min(times * 200, 2000);
  },

  maxRetriesPerRequest: 3,     // fail fast per command

  // handle connection events
  lazyConnect: true,
});

// event listeners for observability
redis.on("connect", () => console.log("Redis connected"));
redis.on("error", (err) => console.error("Redis error:", err.message));

// explicit connect so you catch startup errors early
redis.connect().catch((err) => {
  console.error("Redis initial connection failed:", err.message);
});

export default redis;