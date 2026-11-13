export type OneSignalSdk = {
  init(options: Record<string, unknown>): Promise<void>;
  login(externalId: string): Promise<void>;
  logout(): Promise<void>;
  Notifications: { requestPermission(): Promise<unknown> };
  User: { PushSubscription: { id: string | null; optedIn: boolean; optIn(): Promise<void>; optOut(): Promise<void> } };
};

declare global {
  interface Window {
    OneSignal?: OneSignalSdk;
    OneSignalDeferred?: Array<(sdk: OneSignalSdk) => void | Promise<void>>;
  }
}

let oneSignalPromise: Promise<OneSignalSdk> | null = null;

export function isOneSignalConfigured(): boolean {
  return Boolean(import.meta.env.VITE_ONESIGNAL_APP_ID?.trim());
}

export function loadOneSignal(): Promise<OneSignalSdk> {
  if (typeof window === "undefined" || typeof document === "undefined") {
    return Promise.reject(new Error("Push notifications are available only in a browser"));
  }
  if (window.OneSignal) return Promise.resolve(window.OneSignal);
  if (oneSignalPromise) return oneSignalPromise;

  const appId = import.meta.env.VITE_ONESIGNAL_APP_ID?.trim();
  if (!appId) return Promise.reject(new Error("OneSignal is not configured"));

  oneSignalPromise = new Promise<OneSignalSdk>((resolve, reject) => {
    window.OneSignalDeferred = window.OneSignalDeferred ?? [];
    window.OneSignalDeferred.push(async (sdk) => {
      try {
        await sdk.init({
          appId,
          serviceWorkerPath: "/onesignal/OneSignalSDKWorker.js",
          serviceWorkerParam: { scope: "/onesignal/" },
          notifyButton: { enable: false },
          allowLocalhostAsSecureOrigin: import.meta.env.DEV,
        });
        window.OneSignal = sdk;
        resolve(sdk);
      } catch (error) {
        document.querySelector('script[data-openplay-onesignal="true"]')?.remove();
        oneSignalPromise = null;
        reject(error instanceof Error ? error : new Error("Unable to initialise OneSignal"));
      }
    });

    if (!document.querySelector('script[data-openplay-onesignal="true"]')) {
      const script = document.createElement("script");
      script.src = "https://cdn.onesignal.com/sdks/web/v16/OneSignalSDK.page.js";
      script.defer = true;
      script.dataset.openplayOnesignal = "true";
      script.onerror = () => {
        script.remove();
        oneSignalPromise = null;
        reject(new Error("Unable to load the OneSignal browser SDK"));
      };
      document.head.appendChild(script);
    }
  });

  return oneSignalPromise;
}
