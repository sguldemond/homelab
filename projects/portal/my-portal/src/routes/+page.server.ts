export const load = async ({ fetch }) => {
	const res = await fetch('/api/pods');
	const pods = await res.json();
	return { pods };
};
