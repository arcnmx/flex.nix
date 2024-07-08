{
  inputs = {
    nixpkgs = { };
    flakelib.url = "github:flakelib/fl";
  };
  outputs = { self, flakelib, nixpkgs, ... }@inputs: let
    nixlib = nixpkgs.lib;
  in flakelib {
    inherit inputs;

    packages = {
      adobe-flash-player-bin-debug = ./adobe/flash-player/debug.nix;
      adobe-flex-playerglobal = {
        adobe-flex-playerglobal-32
      }: adobe-flex-playerglobal-32;
      adobe-flex-playerglobal-32 = {
        mkFlexPlayerglobal
      }: mkFlexPlayerglobal {
        version = "32.0";
        sha256 = "sha256-fU1haNJ2A8+zt1AwJEjjVOC7wb3Vj10QHD3PaJHpu2U=";
      };
      adobe-flex-playerglobal-27 = {
        mkFlexPlayerglobal
      }: mkFlexPlayerglobal {
        version = "27.0";
        sha256 = "0qw2bgls8qsmp80j8vpd4c7s0c8anlrk0ac8z42w89bajcdbwk2f";
      };
      adobe-air-sdk-windows = ./adobe/air/windows.nix;
      apache-flex-sdk = ./apache/flex/sdk.nix;
      adobe-flex-sdk-windows = ./adobe/flex/windows.nix;
      adobe-flex-sdk-fontkit-deps = ./adobe/flex/fontkit.nix;
      apache-flex-sdk-full = ./apache/flex/full.nix;
      apache-flash-player-sdk = { stdenvNoCC, writeScript, apache-flex-sdk, adobe-flex-playerglobal }: let
        inherit (adobe-flex-playerglobal) PLAYERGLOBAL_HOME;
      in stdenvNoCC.mkDerivation (drv: {
        pname = "apache-flash-player-sdk";
        version = "${apache-flex-sdk.version}_${adobe-flex-playerglobal.version}";
        dontUnpack = true;
        inherit PLAYERGLOBAL_HOME;
        propagatedBuildInputs = [ apache-flex-sdk adobe-flex-playerglobal ];
      });
      apache-air-sdk = { stdenvNoCC, writeScript, apache-flex-sdk, adobe-air-sdk-windows }: let
        AIR_HOME = adobe-air-sdk-windows.AIRGLOBAL_HOME;
      in stdenvNoCC.mkDerivation (drv: {
        pname = "apache-air-sdk";
        version = "${apache-flex-sdk.version}_${adobe-air-sdk-windows.version}";
        dontUnpack = true;
        inherit AIR_HOME;
        propagatedBuildInputs = [ apache-flex-sdk adobe-air-sdk-windows.airglobal ];
      });
      apache-air-harman-sdk = { stdenvNoCC, writeScript, apache-flex-sdk, harman-air-sdk-flex }: let
        inherit (harman-air-sdk-flex) AIR_HOME PLAYERGLOBAL_HOME;
      in stdenvNoCC.mkDerivation (drv: {
        pname = "apache-air-harman-sdk";
        version = "${apache-flex-sdk.version}_${harman-air-sdk-flex.version}";
        dontUnpack = true;
        inherit AIR_HOME PLAYERGLOBAL_HOME;
        propagatedBuildInputs = [ apache-flex-sdk harman-air-sdk-flex ];
        passthru = {
          inherit harman-air-sdk-flex;
        };
      });
      harman-air-sdk-33 = { mkAirSdkHarman }: mkAirSdkHarman {
        airVersion = "33.1.1.935";
        airSdk = "harman-full";
      };
      harman-air-sdk-51 = { mkAirSdkHarman }: mkAirSdkHarman {
        airVersion = "51.0.1.3";
        airSdk = "harman-full";
      };
      harman-air-sdk-51-flex = { mkAirSdkHarman }: mkAirSdkHarman {
        airVersion = "51.0.1.3";
        airSdk = "harman-flex";
      };
      harman-air-sdk = { harman-air-sdk-51 }: harman-air-sdk-51;
      harman-air-sdk-flex = { harman-air-sdk-51-flex }: harman-air-sdk-51-flex;
    };
    builders = {
      mkFlexPlayerglobal = import ./adobe/flex/playerglobal.nix;
      mkAirSdkHarman = import ./harman/sdk.nix;
      mkFlexSetupHook = { lib, writeScript }: pname: env: let
        env' = if lib.isFunction env
          then env (output: "@${output}@")
          else env;
        mkExport = key: value: "export ${key}=\${${key}-${value}}";
        exports = lib.mapAttrsToList mkExport env';
      in writeScript "${pname}-setup-hook.sh" (lib.concatStringsSep "\n" exports);
    };
    devShells = {
      default = { outputs'devShells'flex }: outputs'devShells'flex;
      flex = { mkShell, apache-flex-sdk, adobe-flash-player-bin-debug, adobe-flex-playerglobal, adobe-air-sdk-windows }: mkShell {
        inherit (adobe-flash-player-bin-debug) FLASHPLAYER_DEBUGGER;
        inherit (adobe-flex-playerglobal) PLAYERGLOBAL_HOME;
        AIR_HOME = adobe-air-sdk-windows.AIRGLOBAL_HOME;
        nativeBuildInputs = [
          apache-flex-sdk
          adobe-flash-player-bin-debug
        ];
      };
      harman-flex = { mkShell, apache-flex-sdk, harman-air-sdk-flex, adobe-flash-player-bin-debug }: mkShell {
        inherit (adobe-flash-player-bin-debug) FLASHPLAYER_DEBUGGER;
        inherit (harman-air-sdk-flex) PLAYERGLOBAL_HOME AIR_HOME AIR_RUNTIME;
        nativeBuildInputs = [
          apache-flex-sdk
          harman-air-sdk-flex
          adobe-flash-player-bin-debug
        ];
      };
      harman = { mkShell, harman-air-sdk, adobe-flash-player-bin-debug }: mkShell {
        inherit (adobe-flash-player-bin-debug) FLASHPLAYER_DEBUGGER;
        inherit (harman-air-sdk) PLAYERGLOBAL_HOME AIR_HOME AIR_RUNTIME;
        nativeBuildInputs = [
          harman-air-sdk
          adobe-flash-player-bin-debug
        ];
      };
    };

    config.name = "flex";
    lib = {
      sdkHome = "lib/air";
      srcs = {
        harman = let
          mkVersion = version: { sha256'linux'full ? null, sha256'linux'flex ? null }: nixlib.nameValuePair version {
            linux = {
              ${if sha256'linux'flex != null then "harman-flex" else null} = {
                requireUrl = "https://airsdk.harman.com/download/${version}";
                name = "AIRSDK_Flex_Linux.zip";
                sha256 = sha256'linux'flex;
              };
              ${if sha256'linux'full != null then "harman-full" else null} = {
                requireUrl = "https://airsdk.harman.com/download/${version}";
                name = "AIRSDK_Linux.zip";
                sha256 = sha256'linux'full;
              };
            };
          };
        in nixlib.listToAttrs [
          (mkVersion "33.1.1.935" {
            sha256'linux'full = "fe770249ab16615e93477dca436b66eba515093e14c06ce617c966e021770252";
          })
          (mkVersion "51.0.1.3" {
            sha256'linux'full = "8b750de48262e372d7b72b9aaa7be50fb6b5a902bfda82807c22f7589ff756e7";
            sha256'linux'flex = "8c6591711f266b69fe522c3c50e5fa5476e9af923e317b2c820d514c3c76bdd9";
          })
        ];
      };
      airRuntimeDir = { airVersion, hostPlatform }: let
        generic = {
          "x86_64-linux" = "linux-x64";
          "aarch64-linux" = "linux-arm64";
          "i686-linux" = "linux";
        }.${hostPlatform.system};
      in if hostPlatform.isAndroid then "android"
        else if hostPlatform.isLinux && nixlib.versionOlder airVersion "50" then "linux"
        else generic;
      airSrcFor = { airVersion, airSdk, hostPlatform, requireFile ? throw "airSrcFor requireFile", fetchurl ? throw "airSrcFor fetchurl" }: let
        requireSrc = let
          harmanPlatform = if hostPlatform.isLinux then "linux" else throw "unsupported harman platform";
          src = self.lib.srcs.harman.${airVersion}.${harmanPlatform}.${airSdk};
        in {
          inherit (src) name sha256;
          url = src.requireUrl;
        };
        forAirSdk = {
          harman-full = requireFile requireSrc;
          harman-flex = requireFile requireSrc;
        };
      in forAirSdk.${airSdk};
    };
  };
}
