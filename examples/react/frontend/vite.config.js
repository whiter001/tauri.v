// vite.config.js — vtauri react 示例前端构建配置
//
// 与 examples/vue 相同：vtauri 通过 set_html 加载单段 HTML 字符串，
// 因此用 vite-plugin-singlefile 把构建产物内联为单个 index.html，
// 再由 V 侧 $embed_file 编译期嵌入可执行文件。
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { viteSingleFile } from 'vite-plugin-singlefile';

export default defineConfig({
  plugins: [react(), viteSingleFile()],
  build: {
    target: 'esnext',
    cssCodeSplit: false,
    assetsInlineLimit: 100000000, // 小资源全部内联，避免独立文件
  },
});
