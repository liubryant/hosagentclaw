export type AppBackHandler = () => boolean;

interface AppBackHandlerEntry {
  id: string;
  handler: AppBackHandler;
}

/**
 * Coordinates custom overlay/page navigation with the system Back action.
 * The most recently mounted secondary surface gets the first chance to go
 * back; returning false lets the request continue toward the root page.
 */
export class AppBackNavigator {
  private static entries: AppBackHandlerEntry[] = [];
  private static nextIdentifier: number = 0;

  static createHandlerId(prefix: string): string {
    AppBackNavigator.nextIdentifier += 1;
    return `${prefix}-${AppBackNavigator.nextIdentifier}`;
  }

  static register(id: string, handler: AppBackHandler): void {
    AppBackNavigator.unregister(id);
    AppBackNavigator.entries.push({ id: id, handler: handler });
  }

  static unregister(id: string): void {
    AppBackNavigator.entries = AppBackNavigator.entries.filter((entry: AppBackHandlerEntry): boolean => {
      return entry.id !== id;
    });
  }

  static handleBack(): boolean {
    const entries = AppBackNavigator.entries.slice();
    for (let index = entries.length - 1; index >= 0; index -= 1) {
      if (entries[index].handler()) {
        return true;
      }
    }
    return false;
  }
}
