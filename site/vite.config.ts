import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

// `npm run build` publie le site dans ../docs, servi par GitHub Pages sur nanousuport-svg.github.io/ElioTV/.
export default defineConfig(({ command }) => ({
  base: command === 'build' ? '/ElioTV/' : '/',
  plugins: [react(), tailwindcss()],
  build: { outDir: '../docs', emptyOutDir: true },
}))
