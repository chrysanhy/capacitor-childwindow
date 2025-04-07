import { registerPlugin } from '@capacitor/core';

import type { ChildWindowPlugin } from './definitions';

const ChildWindow = registerPlugin<ChildWindowPlugin>('ChildWindow', {
  web: () => import('./web').then((m) => new m.ChildWindowWeb()),
});

export * from './definitions';
export { ChildWindow };
