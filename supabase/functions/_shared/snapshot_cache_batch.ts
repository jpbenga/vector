/** Request-local cache: batch factual reads without dropping empty identities,
 * changing exact query selection, or sharing data between publications. */
export class SnapshotCacheBatch<
  T extends { query_params: Record<string, unknown> },
> {
  private groups: Array<{
    endpoint: string;
    filters: Record<string, string>;
    field: string;
    ids: Set<string>;
    rows: T[];
  }> = [];
  constructor(
    private fetch: (
      endpoint: string,
      filters: Record<string, string>,
      field: string,
      ids: string[],
    ) => Promise<T[]>,
  ) {}
  async prefetch(
    endpoint: string,
    filters: Record<string, string>,
    field: string,
    values: Iterable<string>,
  ): Promise<void> {
    const ids = [...new Set(values)];
    const rows: T[] = [];
    for (let start = 0; start < ids.length; start += 25) {
      rows.push(
        ...await this.fetch(
          endpoint,
          filters,
          field,
          ids.slice(start, start + 25),
        ),
      );
    }
    this.groups.push({ endpoint, filters, field, ids: new Set(ids), rows });
  }
  read(
    endpoint: string,
    filters: Record<string, string>,
    exact = false,
  ): T[] | undefined {
    const group = this.groups.find((g) =>
      g.endpoint === endpoint &&
      g.ids.has(filters[g.field]) &&
      Object.entries(g.filters).every(([k, v]) => filters[k] === v)
    );
    if (!group) return undefined;
    return group.rows.filter((row) =>
      Object.entries(filters).every(([k, v]) =>
        String(row.query_params[k] ?? "") === v
      ) &&
      (!exact ||
        Object.keys(row.query_params).length === Object.keys(filters).length)
    );
  }
}
