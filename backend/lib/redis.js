import "dotenv/config";
import Redis from "ioredis";

const MODE = (process.env.REDIS_MODE || "standalone").toLowerCase();
const HOST = process.env.REDIS_HOST;
const PORT = Number(process.env.REDIS_PORT || 6379);
const PASSWORD = process.env.REDIS_PASSWORD || undefined;
const USE_TLS = process.env.REDIS_TLS === "true";

// wait longer after each failed try, max 2 seconds, never give up
const backoff = (times) => Math.min(times * 200, 2000);

// settings used for every connection
const nodeOptions = {
	password: PASSWORD,
	tls: USE_TLS ? {} : undefined,
	connectTimeout: 10000,
	commandTimeout: 5000,
	maxRetriesPerRequest: 3,
  // a replica that is still syncing answers LOADING: reconnect and resend the command
	reconnectOnError: (err) => (err.message.includes("LOADING") ? 2 : false),
};

let client;

if (MODE === "cluster") {
	client = new Redis.Cluster([{ host: HOST, port: PORT }], {
		lazyConnect: true,
		// nodes[0] is the shard's primary, the rest are replicas.
		// Refresh tokens are always read from the primary (replication is async, so a replica
		// can lag). Every other read goes to a random replica. Writes always go to primaries.
		scaleReads: (nodes, command) => {
			const key = String(command.args[0] ?? "");
			if (nodes.length === 1 || key.startsWith("refresh_token:")) return nodes[0];
			return nodes[1 + Math.floor(Math.random() * (nodes.length - 1))];
		},
		clusterRetryStrategy: backoff,
		maxRedirections: 16,
		retryDelayOnFailover: 500,
		retryDelayOnClusterDown: 500,
		retryDelayOnTryAgain: 500,
		slotsRefreshTimeout: 5000,
		// needed for ElastiCache with TLS
		dnsLookup: (address, callback) => callback(null, address),
		redisOptions: nodeOptions,
	});
} else {
	client = new Redis({
		host: HOST,
		port: PORT,
		lazyConnect: true,
		retryStrategy: backoff,
		...nodeOptions,
	});
}

// without this, a Redis error can crash the process
client.on("error", (err) => console.error(`[redis:${MODE}] error:`, err.message));
client.on("ready", () => console.log(`[redis:${MODE}] ready`));

export const redis = client;

// connect at startup, but fail after a time limit instead of hanging forever
export const connectRedis = async (timeoutMs = 30000) => {
	const connecting = (async () => {
		await client.connect();
		await client.ping();
	})();
	connecting.catch(() => {});

	let timer;
	const timeout = new Promise((_, reject) => {
		timer = setTimeout(
			() => reject(new Error(`Redis not reachable after ${timeoutMs / 1000}s`)),
			timeoutMs
		);
	});

	try {
		await Promise.race([connecting, timeout]);
	} finally {
		clearTimeout(timer);
	}
	console.log(`Redis connected (mode: ${MODE})`);
};

export const isRedisHealthy = async () => {
	try {
		return (await client.ping()) === "PONG";
	} catch {
		return false;
	}
};
