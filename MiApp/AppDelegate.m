#import "AppDelegate.h"
#import "ViewController.h"
#import "HomeViewController.h"
#import "MainSettingsViewController.h"
#import "LicenseViewController.h"
#import "LicenseValidator.h"
#import "ScreenProtectionManager.h"
#import "AppVersionChecker.h"
#import "AppVersionLockViewController.h"
#import "sandbox_escape.h"
#import <mach-o/dyld.h>
#include <string.h>
#include <unistd.h>

static BOOL XITForgeFilzaEngineLoaded(void) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *imageName = _dyld_get_image_name(i);
        if (!imageName) continue;
        if (strstr(imageName, "FilzaApplySandboxExt.dylib") != NULL) {
            return YES;
        }
    }
    return NO;
}

static BOOL XITForgeSandboxEscaped = NO;

static void XITForgeEjecutarSandboxEscape(void) {
    if (XITForgeSandboxEscaped) return;
    
    uint64_t self_proc = proc_self();
    if (!self_proc) {
        NSLog(@"XITFORGE: No se pudo obtener self_proc");
        return;
    }
    
    NSLog(@"XITFORGE: Ejecutando sandbox escape...");
    int result = sandbox_escape(self_proc);
    
    if (result == 0) {
        XITForgeSandboxEscaped = YES;
        NSLog(@"XITFORGE: Sandbox escape exitoso");
        
        int elevateResult = sandbox_elevate_to_root(self_proc);
        if (elevateResult == 0) {
            NSLog(@"XITFORGE: Elevación a root exitosa");
        } else {
            NSLog(@"XITFORGE: Elevación a root falló con código %d", elevateResult);
        }
    } else {
        NSLog(@"XITFORGE: Sandbox escape falló con código %d", result);
    }
}

@interface AppDelegate ()
@property (nonatomic, strong) UIWindow *lockWindow;
@property (nonatomic, strong) UITabBarController *mainTabBar;
@property (nonatomic, strong) UIWindow *versionWindow;
@property (nonatomic, assign) BOOL versionCheckInProgress;
@property (nonatomic, assign) BOOL initialVersionGateCompleted;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    BOOL filzaEngineLoaded = XITForgeFilzaEngineLoaded();
    [[NSUserDefaults standardUserDefaults] setBool:filzaEngineLoaded forKey:@"XITForgeFilzaEngineLoaded"];
    
    // ✅ EJECUTAR SANDBOX ESCAPE AL INICIO
    XITForgeEjecutarSandboxEscape();
    
    UIColor *acento = [UIColor colorWithRed:0.2 green:1.0 blue:0.5 alpha:1.0];
    
    UINavigationBarAppearance *ap = [[UINavigationBarAppearance alloc] init];
    [ap configureWithOpaqueBackground];
    ap.backgroundColor = [UIColor blackColor];
    ap.shadowColor = [UIColor colorWithWhite:0.25 alpha:1.0];
    ap.titleTextAttributes = @{
        NSForegroundColorAttributeName: acento,
        NSFontAttributeName: [UIFont fontWithName:@"Menlo-Bold" size:17.0]
    };
    [[UINavigationBar appearance] setStandardAppearance:ap];
    [[UINavigationBar appearance] setScrollEdgeAppearance:ap];
    [[UINavigationBar appearance] setTintColor:acento];
    
    UITabBarAppearance *tabAppearance = [[UITabBarAppearance alloc] init];
    [tabAppearance configureWithOpaqueBackground];
    tabAppearance.backgroundColor = [UIColor blackColor];
    [[UITabBar appearance] setStandardAppearance:tabAppearance];
    [[UITabBar appearance] setScrollEdgeAppearance:tabAppearance];
    [[UITabBar appearance] setTintColor:acento];
    [[UITabBar appearance] setUnselectedItemTintColor:[UIColor grayColor]];
    
    HomeViewController *homeVC = [[HomeViewController alloc] init];
    UINavigationController *homeNav = [[UINavigationController alloc] initWithRootViewController:homeVC];
    homeNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Inicio" image:[UIImage systemImageNamed:@"house.fill"] tag:0];
    
    ViewController *explorerVC = [[ViewController alloc] init];
    UINavigationController *explorerNav = [[UINavigationController alloc] initWithRootViewController:explorerVC];
    explorerNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Explorar" image:[UIImage systemImageNamed:@"magnifyingglass"] tag:1];
    
    MainSettingsViewController *settingsVC = [[MainSettingsViewController alloc] init];
    UINavigationController *settingsNav = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    settingsNav.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Ajustes" image:[UIImage systemImageNamed:@"gearshape.fill"] tag:2];
    
    UIColor *settingsRed = [UIColor colorWithRed:0.95 green:0.08 blue:0.10 alpha:1.0];
    UINavigationBarAppearance *settingsAppearance = [[UINavigationBarAppearance alloc] init];
    [settingsAppearance configureWithOpaqueBackground];
    settingsAppearance.backgroundColor = [UIColor blackColor];
    settingsAppearance.shadowColor = [UIColor colorWithWhite:0.25 alpha:1.0];
    NSDictionary *settingsTitleAttributes = @{
        NSForegroundColorAttributeName: settingsRed,
        NSFontAttributeName: [UIFont fontWithName:@"Menlo-Bold" size:17.0]
    };
    settingsAppearance.titleTextAttributes = settingsTitleAttributes;
    settingsAppearance.largeTitleTextAttributes = @{
        NSForegroundColorAttributeName: settingsRed,
        NSFontAttributeName: [UIFont boldSystemFontOfSize:32.0]
    };
    settingsNav.navigationBar.standardAppearance = settingsAppearance;
    settingsNav.navigationBar.scrollEdgeAppearance = settingsAppearance;
    settingsNav.navigationBar.compactAppearance = settingsAppearance;
    settingsNav.navigationBar.tintColor = settingsRed;
    
    self.mainTabBar = [[UITabBarController alloc] init];
    self.mainTabBar.viewControllers = @[homeNav, explorerNav, settingsNav];
    self.mainTabBar.selectedIndex = 0;
    
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    
    UIViewController *versionGatePlaceholder = [[UIViewController alloc] init];
    versionGatePlaceholder.view.backgroundColor = [UIColor blackColor];
    self.window.rootViewController = versionGatePlaceholder;
    [self.window makeKeyAndVisible];
    
    [self applySavedScreenProtection];
    [self verificarVersionDeApp];
    
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    if (self.window && !self.versionCheckInProgress) {
        [self verificarVersionDeApp];
    }
}

#pragma mark - App Version Gate
- (void)verificarVersionDeApp {
    if (self.versionCheckInProgress) return;
    self.versionCheckInProgress = YES;
    __weak typeof(self) weakSelf = self;
    [AppVersionChecker checkWithCompletion:^(BOOL success, BOOL blocked, BOOL updateAvailable, NSString *currentVersion, NSString *latestVersion, NSString *minimumVersion, NSString *message, NSString *downloadURL, NSString * _Nullable errorMessage) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.versionCheckInProgress = NO;
        if (!success) {
            [strongSelf mostrarBloqueoDeVersionConTitulo:@"No se pudo verificar la versión" mensaje:(errorMessage.length > 0 ? errorMessage : @"Comprueba tu conexión a Internet y vuelve a intentarlo.") versionActual:currentVersion versionRequerida:@"" downloadURL:@"" mostrarDescarga:NO];
            return;
        }
        if (blocked) {
            NSString *finalMessage = message.length > 0 ? message : @"Esta versión de XITFORGE ya no está disponible. Descarga la nueva versión para continuar.";
            NSString *required = minimumVersion.length > 0 ? minimumVersion : latestVersion;
            [strongSelf mostrarBloqueoDeVersionConTitulo:@"Actualización requerida" mensaje:finalMessage versionActual:currentVersion versionRequerida:required downloadURL:downloadURL mostrarDescarga:(downloadURL.length > 0)];
            return;
        }
        BOOL firstSuccessfulVersionCheck = !strongSelf.initialVersionGateCompleted;
        if (firstSuccessfulVersionCheck) {
            strongSelf.initialVersionGateCompleted = YES;
            strongSelf.window.rootViewController = strongSelf.mainTabBar;
        }
        [strongSelf cerrarBloqueoDeVersion];
        if (firstSuccessfulVersionCheck) {
            [strongSelf mostrarPantallaLicencia];
        }
    }];
}

- (void)mostrarBloqueoDeVersionConTitulo:(NSString *)titulo mensaje:(NSString *)mensaje versionActual:(NSString *)versionActual versionRequerida:(NSString *)versionRequerida downloadURL:(NSString *)downloadURL mostrarDescarga:(BOOL)mostrarDescarga {
    AppVersionLockViewController *vc = nil;
    if ([self.versionWindow.rootViewController isKindOfClass:[AppVersionLockViewController class]]) {
        vc = (AppVersionLockViewController *)self.versionWindow.rootViewController;
    }
    if (!vc) {
        vc = [[AppVersionLockViewController alloc] init];
        self.versionWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        self.versionWindow.windowLevel = UIWindowLevelAlert + 10;
        self.versionWindow.backgroundColor = [UIColor blackColor];
        self.versionWindow.rootViewController = vc;
    }
    vc.headline = titulo ?: @"";
    vc.messageText = mensaje ?: @"";
    vc.currentVersion = versionActual ?: @"";
    vc.requiredVersion = versionRequerida ?: @"";
    vc.downloadURL = downloadURL ?: @"";
    vc.showDownloadButton = mostrarDescarga;
    __weak typeof(self) weakSelf = self;
    vc.retryHandler = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) [strongSelf verificarVersionDeApp];
    };
    [self.versionWindow makeKeyAndVisible];
}

- (void)cerrarBloqueoDeVersion {
    if (!self.versionWindow) {
        [self.window makeKeyAndVisible];
        return;
    }
    [self.versionWindow resignKeyWindow];
    self.versionWindow.hidden = YES;
    self.versionWindow.rootViewController = nil;
    self.versionWindow = nil;
    [self.window makeKeyAndVisible];
}

#pragma mark - Screen Protection
- (void)applySavedScreenProtection {
    BOOL enabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"screenProtection"];
    if (enabled) {
        [[ScreenProtectionManager shared] enableProtection];
    } else {
        [[ScreenProtectionManager shared] disableProtection];
    }
}

#pragma mark - License Validation
- (void)mostrarPantallaLicencia {
    NSString *savedKey = [[NSUserDefaults standardUserDefaults] stringForKey:@"MiFilzaLicenseKey"];
    if (savedKey.length == 0) {
        [self mostrarVentanaDeLicencia];
        return;
    }
    [LicenseValidator validateKey:savedKey completion:^(BOOL valid, NSString * _Nullable reason, NSString * _Nullable expiresAt) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (valid) {
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                if (expiresAt.length > 0) {
                    [defaults setObject:expiresAt forKey:@"MiFilzaLicenseExpiresAt"];
                } else {
                    [defaults removeObjectForKey:@"MiFilzaLicenseExpiresAt"];
                }
                [defaults synchronize];
                [self applySavedScreenProtection];
                return;
            }
            NSLog(@"XITFORGE License rejected: %@", reason);
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [defaults removeObjectForKey:@"MiFilzaLicenseKey"];
            [defaults removeObjectForKey:@"MiFilzaLicenseExpiresAt"];
            [defaults synchronize];
            [[ScreenProtectionManager shared] disableProtection];
            [self mostrarVentanaDeLicencia];
        });
    }];
}

#pragma mark - License Window
- (void)mostrarVentanaDeLicencia {
    if (self.lockWindow) {
        [self.lockWindow makeKeyAndVisible];
        return;
    }
    LicenseViewController *licenseVC = [[LicenseViewController alloc] init];
    licenseVC.modalPresentationStyle = UIModalPresentationFullScreen;
    __weak typeof(self) weakSelf = self;
    licenseVC.onLicenseValidated = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            [strongSelf applySavedScreenProtection];
            [strongSelf.lockWindow resignKeyWindow];
            strongSelf.lockWindow.hidden = YES;
            strongSelf.lockWindow = nil;
            [strongSelf.window makeKeyAndVisible];
        });
    };
    self.lockWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.lockWindow.windowLevel = UIWindowLevelAlert + 1;
    self.lockWindow.backgroundColor = [UIColor blackColor];
    self.lockWindow.rootViewController = [[UIViewController alloc] init];
    [self.lockWindow makeKeyAndVisible];
    [self.lockWindow.rootViewController presentViewController:licenseVC animated:YES completion:nil];
}

- (void)logoutCurrentLicense {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:@"MiFilzaLicenseKey"];
    [defaults removeObjectForKey:@"MiFilzaLicenseExpiresAt"];
    [defaults synchronize];
    [[ScreenProtectionManager shared] disableProtection];
    [self mostrarVentanaDeLicencia];
}

- (BOOL)validarFormatoLicencia:(NSString *)licencia {
    if (licencia.length == 0) return NO;
    NSString *regex = @"^[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$";
    NSPredicate *predicado = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex];
    return [predicado evaluateWithObject:licencia];
}

@end
