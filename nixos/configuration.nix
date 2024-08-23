# This is your system's configuration file.
# Use this to configure your system environment (it replaces /etc/nixos/configuration.nix)
{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}: {
  # You can import other NixOS modules here
  imports = [
    # If you want to use modules your own flake exports (from modules/nixos):
    # outputs.nixosModules.example

    # Or modules from other flakes (such as nixos-hardware):
    # inputs.hardware.nixosModules.common-cpu-amd
    # inputs.hardware.nixosModules.common-ssd

    # You can also split up your configuration and import pieces of it here:
    # ./users.nix

    # Import your generated (nixos-generate-config) hardware configuration
    ./hardware-configuration.nix
  ];

  boot = {
    # Kernel
    kernelPackages = pkgs.linuxPackages_zen;
    # This is for OBS Virtual Cam Support
    kernelModules = [ "v4l2loopback" ];
    extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
    # Needed For Some Steam Games
    kernel.sysctl = {
      "vm.max_map_count" = 2147483642;
    };
    # Bootloader.
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    # Appimage Support
    binfmt.registrations.appimage = {
      wrapInterpreterInShell = false;
      interpreter = "${pkgs.appimage-run}/bin/appimage-run";
      recognitionType = "magic";
      offset = 0;
      mask = ''\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff'';
      magicOrExtension = ''\x7fELF....AI\x02'';
    };
    plymouth.enable = true;
  };

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages

      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };

  nix = let
    flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
  in {
    settings = {
      # Enable flakes and new 'nix' command
      experimental-features = "nix-command flakes";
      # Opinionated: disable global registry
      flake-registry = "";
      # Workaround for https://github.com/NixOS/nix/issues/9574
      nix-path = config.nix.nixPath;
      auto-optimise-store = true;

      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 7d";
      };
    };
    # Opinionated: disable channels
    channel.enable = false;

    # Opinionated: make flake registry and nix path match flake inputs
    registry = lib.mapAttrs (_: flake: {inherit flake;}) flakeInputs;
    nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;
  };

  # FIXME: Add the rest of your current configuration

  # virtualization / containers
  virtualisation.libvirtd.enable = true;
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  networking.networkmanager.enable = true;
  networking.hostName = "lancelot";


  # for AMD drivers
  systemd.tmpfiles.rules = [ "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}" ];
  services.xserver.videoDrivers = [ "amdgpu" ];

  # for windows compatibility
  time.hardwareClockInLocalTime = true;

  # locale etc
  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_GB.UTF-8";
    LC_IDENTIFICATION = "en_GB.UTF-8"; 
    LC_MEASUREMENT = "en_GB.UTF-8";
    LC_MONEY = "en_GB.UTF-8"; 
    LC_NAME = "en_GB.UTF-8";
    LC_PAPER = "en_GB.UTF-8";
    LC_TELEPHONE = "en_GB.UTF-8";
    LC_TIME = "en_GB.UTF-8";
  };

  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  services.xserver.xkb = {
    layout = "gb"; 
    variant = "";
  };

  console.keyMap = "uk";

  services.printing.enable = true;

  hardware.pulseaudio.enable = false;

  # security
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # TODO: Configure your system-wide user settings (groups, etc), add more users as needed.
  users.users = {
    # FIXME: Replace with your username
    rai = {
      # TODO: You can set an initial password for your user.
      # If you do, you can skip setting a root password by passing '--no-root-passwd' to nixos-install.
      # Be sure to change it (using passwd) after rebooting!
      initialPassword = "changeme";
      isNormalUser = true;
      openssh.authorizedKeys.keys = [
        # TODO: Add your SSH public key(s) here, if you plan on using SSH to connect
      ];
      # TODO: Be sure to add any other groups you need (such as networkmanager, audio, docker, etc)
      extraGroups = ["networkmanager" "wheel" "libvirtd" "scanner" "lp"];
      shell = pkgs.zsh;
      # TODO: find out what this is
      ignoreShellProgramCheck = true;

    };
  };

  users.mutableUsers = true;

  # TODO: what is this??
  hardware.sane = {
    enable = true;
    extraBackends = [ pkgs.sane-airscan ];

    disabledDefaultBackends = ["escl"];
  };

  # This setups a SSH server. Very important if you're setting up a headless system.
  # Feel free to remove if you don't need it.
  services.openssh = {
    enable = true;
    settings = {
      # Opinionated: forbid root login through SSH.
      PermitRootLogin = "no";
      # Opinionated: use keys only.
      # Remove if you want to SSH using passwords
      PasswordAuthentication = false;
    };
  };

  environment.systemPackages = with pkgs; [
    # core
    lld
    gcc 
    glibc
    clang 
    udev
    llvmPackages.bintools
    wget
    procps
    killall
    zip
    unzip
    bluez
    busybox
    bluez-tools
    brightnessctl
    light
    xdg-utils
    pkg-config
    kdePackages.qtsvg
    usbutils
    lxqt.lxqt-policykit
    gnumake

    # general
    networkmanagerapplet
    git
    fzf
    vim
    tldr
    sox
    neovim
    yad
    ffmpeg
    imagemagick
    
    # shell
    zsh
    tree
    eza
    ## TODO: figure out how to remove this
    oh-my-zsh
    zsh-powerlevel10k
    nix-search-cli
    
    # personal

    # development
    asdf-vm
    typescript-language-server
    nil
    go
    wl-clipboard
    clipman
    ack
    aria2
    bfg-repo-cleaner
    boost
    broot
    caddy
    cario
    ctags
    fb303
    fbthrift
    fd
    findutils
    fizz
    folly
    fzf
    fzy
    gettext
    git-filter-repo
    git-lfs
    git-secret
    glib
    glow
    gnupg
    gnutls
    gobject-introspection
    guile
    harfbuzz
    htop
    httpie
    krb5
    leptonica
    libbluray
    librsvg
    libssh2
    lua
    mkcert
    mono
    sbctl
    ncdu
    openssl
    p11-kit
    p7zip
    pandoc
    peco
    perl
    pyenv
    readline
    ripgrep
    todoist
    shellcheck
    sphinx
    stylua
    tesseract
    tmux
    unbound
    vapoursynth
    wangle
    watchman
    libwebp
    wget
    wimlib
    wireguard-tools
    zlib
    xz
    virtualenv
    SDL2
    delta
    gitflow
    postgresql
    ntfs3g
    fuse
    bun
    pnpm
    xclip
    stow

    # LSPs
    rust-analyzer
    lua-language-server
    pyright
    tailwindcss
    svelte-language-server
    yaml-language-server
    gopls
    gleam
    json-language-server
    bash-language-server
    coc-tsserver
    prettierd


    

    
    # gtk
    gtk2
    gtk3
    gtk4
    tela-circle-icon-theme
    bibata-cursors

    # qt
    qtcreator
    qt5.qtwayland
    qt6.qtwayland
    qt6.qmake
    libsForQt5.qt5.qtwayland
    qt5ct
    gsettings-qt

    # misc
    helix
    dolphin
    xfce.thunar
    bat
    discord
    cava
    fastfetch
    cpufetch
    starship
    lolcat
    transmission_4-gtk
    slurp
    vlc
    mpv
    krabby
    zellij
    shellcheck
    thefuck
    gthumb
    cmatrix
    lagrange
    lavat
    localsend
    obs-studio

    # xorg
    xorg.libX11
    xorg.libXcursor

    # hyprdots dependencies
    hyprland
    waybar
    xwayland
    cliphist
    alacritty
    kitty
    swww
    swaynotificationcenter
    lxde.lxsession
    gtklock
    eww
    xdg-desktop-portal-hyprland
    ## TODO: enable this when i figure out how to inject inputs
    ## inputs.hyprwm-contrib.packages.${system}.grimblast
    where-is-my-sddm-theme
    firefox
    brave
    pavucontrol
    blueman
    trash-cli
    ydotool
    lsd
    parallel
    pwvucontrol
    pamixer
    udiskie
    dunst
    swaylock-effects
    wlogout
    hyprpicker
    slurp
    swappy
    polkit_gnome
    libinput-gestures
    jq
    kdePackages.qtimageformats
    kdePackages.ffmpegthumbs
    kdePackages.kde-cli-tools
    libnotify
    libsForQt5.qt5.qtquickcontrols
    libsForQt5.qt5.qtquickcontrols2
    libsForQt5.qt5.qtgraphicaleffects
    libsForQt5.qt5.qt5ct
    libsForQt5.qt5.qtstyleplugin-kvantum
    kdePackages.qtstyleplugin-kvantum
    kdePackages.qt6ct
    kdePackages.wayland
    rofi-wayland
    nwg-look
    ark
    hyprcursor
    pokemon-colorscripts-mac
  ];

  fonts.fontDir.enable = true;
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-emoji
    noto-fonts-cjk
    nerdfonts
    symbola
    noto-fonts-color-emoji
    material-icons
    font-awesome
    atkinson-hyperlegible
    monaspace
    inter
    lato
    roboto
  ];

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "24.05";
}
