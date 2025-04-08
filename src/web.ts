import { WebPlugin } from '@capacitor/core';
import type { ChildWindowPlugin } from './definitions';

export class ChildWindowWeb extends WebPlugin implements ChildWindowPlugin {
  private iframe: HTMLIFrameElement | null = null;
  private container: HTMLDivElement | null = null;
  private touchStartX: number = 0;
  
  async open(options: { url: string }): Promise<void> {
    if (!this.container) {
      // First-time setup - create container for the iframe
      this.container = document.createElement('div');
      this.container.style.position = 'fixed';
      this.container.style.top = '0';
      this.container.style.left = '0';
      this.container.style.width = '100%';
      this.container.style.height = '100%';
      this.container.style.backgroundColor = 'white';
      this.container.style.zIndex = '9999';
      
      // Create iframe
      this.iframe = document.createElement('iframe');
      this.iframe.style.width = '100%';
      this.iframe.style.height = '100%';
      this.iframe.style.border = 'none';
      this.iframe.style.overflow = 'hidden';
      
      // Add meta tag to disable zoom and horizontal scroll
      const meta = document.createElement('meta');
      meta.name = 'viewport';
      meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
      document.head.appendChild(meta);
      
      // Set up event handlers
      this.iframe.onerror = () => {
        this.notifyListeners('loaderror', {
          url: this.iframe?.src || '',
          errorCode: -1,
          errorDescription: 'Failed to load page'
        });
      };
      
      // Handle navigation interception
      this.iframe.onload = () => {
        try {
          const iframeWindow = this.iframe?.contentWindow;
          if (iframeWindow) {
            // Handle document clicks to intercept navigation
            iframeWindow.document.addEventListener('click', (e) => {
              const target = e.target as HTMLElement;
              const linkElement = target.closest('a');
              
              if (linkElement && linkElement.href) {
                e.preventDefault();
                
                // Notify navigate event
                this.notifyListeners('navigate', { url: linkElement.href });
                
                // Navigation is now controlled by JavaScript through open() calls
                // Do NOT automatically load the URL here
              }
            });
            
            // Override form submissions
            const forms = iframeWindow.document.forms;
            for (let i = 0; i < forms.length; i++) {
              forms[i].addEventListener('submit', (e) => {
                e.preventDefault();
                const form = e.target as HTMLFormElement;
                const url = form.action;
                
                // Notify navigate event
                this.notifyListeners('navigate', { url });
                
                // Do NOT automatically submit the form
                // Let JavaScript call open() if it decides to allow
              });
            }
            
            // Check for errors in loaded content
            const contentDocument = this.iframe?.contentDocument;
            if (contentDocument && (
              contentDocument.title.includes('Error') || 
              contentDocument.body.textContent?.includes('404') ||
              contentDocument.body.textContent?.includes('Not Found')
            )) {
              this.notifyListeners('loaderror', {
                url: this.iframe?.src || '',
                errorCode: -1,
                errorDescription: 'Page loaded with error status'
              });
            }
          }
        } catch (e) {
          // Handle cross-origin restrictions
          console.warn('Cannot access iframe content due to same-origin policy. Navigation interception limited.');
        }
      };
      
      // Handle swipe gesture
      this.container.addEventListener('touchstart', (e) => {
        this.touchStartX = e.touches[0].clientX;
      });
      
      this.container.addEventListener('touchend', (e) => {
        const touchEndX = e.changedTouches[0].clientX;
        const diffX = touchEndX - this.touchStartX;
        
        // Detect left-to-right swipe
        if (diffX > 100) {
          this.notifyListeners('exit', {});
          this.closeInternal();
        }
      });
      
      // Add iframe to container and container to body
      this.container.appendChild(this.iframe);
      document.body.appendChild(this.container);
      
      // Lock orientation to portrait (if supported by browser)
      if (screen.orientation) {
        try {
          await screen.orientation.lock('portrait');
        } catch (e) {
          console.warn('Could not lock screen orientation');
        }
      }
      
      // Apply CSS to disable overscroll on body
      const style = document.createElement('style');
      style.textContent = `
        body { overscroll-behavior: none; overflow-x: hidden; }
        html, body { position: fixed; width: 100%; }
      `;
      document.head.appendChild(style);
    }
    
    // Load the URL in the iframe
    if (this.iframe) {
      this.iframe.src = options.url;
    }
  }
  
  private closeInternal(): void {
    if (this.container && this.container.parentNode) {
      this.container.parentNode.removeChild(this.container);
      this.container = null;
      this.iframe = null;
      
      // Remove any styles we added
      const metaViewport = document.querySelector('meta[name="viewport"][content*="user-scalable=no"]');
      if (metaViewport && metaViewport.parentNode) {
        metaViewport.parentNode.removeChild(metaViewport);
      }
    }
    
    // Reset orientation lock if applied
    if (screen.orientation) {
      try {
        screen.orientation.unlock();
      } catch (e) {
        // Ignore
      }
    }
  }
  
  async close(): Promise<void> {
    this.closeInternal();
  }
}