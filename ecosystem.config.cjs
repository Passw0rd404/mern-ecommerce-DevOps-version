module.exports = {
  apps: [
    {
      name: "ecommerce-backend",
      cwd: __dirname,
      script: "backend/server.js",
      node_args: "--import ./tracing.js",
      exec_mode: "fork",
      instances: 1,
      kill_timeout: 12000, // lets server.js close connections before PM2 force-kills it
      min_uptime: "10s",
      max_restarts: 10,
    },
  ],
};
