import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
	plugins: [sveltekit()],
	server: {
		allowedHosts: ['portal.macmini.home']
	},
	preview: {
		allowedHosts: ['portal.macmini.home']
	}
});
