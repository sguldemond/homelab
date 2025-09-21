import type { RequestHandler } from '@sveltejs/kit';
import * as k8s from '@kubernetes/client-node';

export const GET: RequestHandler = async ({ url }) => {
	const ns = url.searchParams.get('ns') ?? '';
	const kc = new k8s.KubeConfig();

	// TODO: this try/catch doesn't work
	// try { kc.loadFromCluster(); } catch { kc.loadFromDefault(); }
	kc.loadFromDefault();

	const k8sApi = kc.makeApiClient(k8s.CoreV1Api);
	const res = ns
		? await k8sApi.listNamespacedPod({ namespace: ns })
		: await k8sApi.listPodForAllNamespaces();

	return new Response(JSON.stringify(res.items), {
		headers: { 'content-type': 'application/json' }
	});
};
