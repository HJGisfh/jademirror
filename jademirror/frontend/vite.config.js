import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import path from 'node:path'

// https://vite.dev/config/
export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  server: {
    // 固定端口，终端始终提示同一地址；若访问 127.0.0.1，由 main.js 在开发环境重定向到 localhost
    port: 5173,
    strictPort: true,
    proxy: {
      '/api': {
        target: process.env.VITE_BACKEND_ORIGIN || 'http://127.0.0.1:5000',
        changeOrigin: true,
      },
    },
  },
})
