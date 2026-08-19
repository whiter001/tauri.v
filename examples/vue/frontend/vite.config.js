// vite.config.js — vtauri vue 示例前端构建配置
//
// 关键点：vtauri 目前只通过 set_html 加载一段 HTML 字符串（没有静态资源服务器），
// 因此用 vite-plugin-singlefile 把构建产物的 JS/CSS 全部内联为单个 index.html，
// 再由 V 侧 $embed_file 编译期嵌入可执行文件。
import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';
import { viteSingleFile } from 'vite-plugin-singlefile';

export default defineConfig({
  plugins: [vue(), viteSingleFile()],
  build: {
    target: 'esnext',
    cssCodeSplit: false,
    assetsInlineLimit: 100000000, // 小资源全部内联，避免独立文件
  },
});
