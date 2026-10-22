import { defineConfig } from 'vite';

export default defineConfig({
  base: '/TribesRevival/',
  server: {
    host: true,        // escucha en todas las interfaces (0.0.0.0) para permitir acceso desde el móvil
    port: 5173,
    strictPort: true,
  },
});
