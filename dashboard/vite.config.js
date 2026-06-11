// Vite 构建配置：集成 React 和 Tailwind CSS，并将 /api 请求代理到本地仪表板服务器
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    proxy: {
      '/api': 'http://127.0.0.1:7842',
    },
  },
});
