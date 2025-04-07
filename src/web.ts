import { WebPlugin } from '@capacitor/core';

import type { ChildWindowPlugin } from './definitions';

export class ChildWindowWeb extends WebPlugin implements ChildWindowPlugin {
  async echo(options: { value: string }): Promise<{ value: string }> {
    console.log('ECHO', options);
    return options;
  }
}
