<script lang="ts">
	import type { PageProps } from './$types';
	import {
		Table,
		TableHead,
		TableHeadCell,
		TableBody,
		TableBodyRow,
		TableBodyCell
	} from 'flowbite-svelte';

	let { data }: PageProps = $props();
</script>

<div class="p-8">
    <h1 class="text-3xl font-bold mb-6">Portal</h1>
    <p class="text-gray-600 mb-8 max-w-3xl leading-relaxed">
        Here is a little insight into my <a href="https://github.com/sguldemond/homelab" class="text-primary-600 hover:underline">Homelab K3s cluster</a>. This is a live view of the pods running on there.
    </p>
</div>

<Table>
	<TableHead>
		<TableHeadCell>Name</TableHeadCell>
		<TableHeadCell>Namespace</TableHeadCell>
		<TableHeadCell>Status</TableHeadCell>
		<TableHeadCell>Restarts</TableHeadCell>
	</TableHead>
	<TableBody>
		{#each data.pods as p}
			<TableBodyRow>
				<TableBodyCell>{p.metadata?.name}</TableBodyCell>
				<TableBodyCell>{p.metadata?.namespace}</TableBodyCell>
				<TableBodyCell>{p.status?.phase}</TableBodyCell>
				<TableBodyCell
					>{(p.status?.containerStatuses ?? []).reduce(
						(n: number, c: any) => n + (c.restartCount || 0),
						0
					)}</TableBodyCell
				>
			</TableBodyRow>
		{/each}
	</TableBody>
</Table>
