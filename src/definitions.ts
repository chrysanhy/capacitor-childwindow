export interface ChildWindowPlugin {
  /**
   * Open a URL in an in-app browser
   * @param options Options for the in-app browser
   * @returns Promise that resolves when the browser has been opened
   */
  open(options: { url: string }): Promise<void>;
  
  /**
   * Close the in-app browser
   * @returns Promise that resolves when the browser has been closed
   */
  close(): Promise<void>;
}

/**
 * Listener events emitted by the plugin
 */
export interface ChildWindowListeners {
  /**
   * Called when an error occurs while loading a page
   */
  loaderror: {
    url: string;
    errorCode: number;
    errorDescription: string;
  };
  
  /**
   * Called before a page is loaded
   */
  beforeload: {
    url: string;
  };
  
  /**
   * Called when the user performs a swipe gesture to exit
   */
  exit: void;
}