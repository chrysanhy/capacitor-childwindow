export interface ChildWindowPlugin {
  echo(options: { value: string }): Promise<{ value: string }>;
}
