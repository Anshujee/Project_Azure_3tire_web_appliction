/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',  // bundles only what's needed — produces a smaller Docker image
  env: {
    NEXT_PUBLIC_API_URL: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080',
  },
};

module.exports = nextConfig;
