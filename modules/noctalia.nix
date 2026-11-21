{ pkgs, inputs, ... }:

{
  home-manager.users.nettzsu = {
    # Import the home manager module
    imports = [
      inputs.noctalia.homeModules.default
    ];

    programs.noctalia = {
      enable = true;
      settings = {
        # Configure options
	shell.font = "Iosevka Nerd Font";
	wallpaper = {
	  enabled = true;
          directory = "/home/nettzsu/nixfiles/wallpapers/";
          fill_mode = "crop";

          default = {
            path = "/home/nettzsu/nixfiles/wallpapers/nixos02.png";
          };
	};
      };
    };
  };
}
