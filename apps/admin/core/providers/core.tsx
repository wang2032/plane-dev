import { ThemeProvider } from "next-themes";
import { SWRConfig } from "swr";
import { TranslationProvider } from "@plane/i18n";
import { AppProgressBar } from "@/lib/b-progress";
// local imports
import { ToastWithTheme } from "./toast";
import { StoreProvider } from "./store.provider";
import { InstanceProvider } from "./instance.provider";
import { UserProvider } from "./user.provider";

const DEFAULT_SWR_CONFIG = {
  refreshWhenHidden: false,
  revalidateIfStale: false,
  revalidateOnFocus: false,
  revalidateOnMount: true,
  refreshInterval: 600_000,
  errorRetryCount: 3,
};

export function CoreProviders({ children }: { children: React.ReactNode }) {
  return (
    <ThemeProvider themes={["light", "dark"]} defaultTheme="system" enableSystem>
      <AppProgressBar />
      <ToastWithTheme />
      <SWRConfig value={DEFAULT_SWR_CONFIG}>
        <TranslationProvider>
          <StoreProvider>
            <InstanceProvider>
              <UserProvider>{children}</UserProvider>
            </InstanceProvider>
          </StoreProvider>
        </TranslationProvider>
      </SWRConfig>
    </ThemeProvider>
  );
}
