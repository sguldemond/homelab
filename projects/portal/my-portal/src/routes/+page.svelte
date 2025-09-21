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

<h1 class="text-2xl font-semibold mb-4">Pods</h1>
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
