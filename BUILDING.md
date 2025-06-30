# Building Equinox
This aims to be a comprehensive guide to compiling Equinox from scratch. If your distribution has a package for Equinox, you needn't do this.

# Installation
## Dependencies Required (For people interested in packaging Equinox)
### Library Dependencies
1. glib
2. [libgbinder](https://github.com/mer-hybris/libgbinder)
3. pcre2
4. gtk4
5. libadwaita

### Compile-Time Dependencies
1. clang
2. make

### Runtime Dependencies
1. lxc
2. dnsmasq

## Arch
Run the following command to gather all dependencies needed by Equinox on Arch Linux.
```
# pacman -S clang make gtk4 libadwaita glib2 glib2-devel pcre2 lxc dnsmasq
```
Now, you need to install libgbinder, which you can do by using your favourite AUR helper (we're using `yay` in this example, but you can use any AUR helper you fancy.)

```
# yay -S libgbinder
```

Some users have reported that the following command fails. If it does, run this command instead:

```
# yay -S libgbinder-git
```

## Fedora
Run the following command to gather all dependencies needed by Equinox on Fedora.
```
# dnf install libgbinder-devel libgbinder libglibutil-devel clang gtk4 gtk4-devel libadwaita libadwaita-devel pcre2 pcre2-devel glib2 glib2-devel lxc dnsmasq
```

**NOTICE**: Fedora uses [SELinux](https://en.wikipedia.org/wiki/Security-Enhanced_Linux) by default. Equinox cannot work with it yet. Hence, you'll need to disable SELinux.

### Disabling SELinux
SELinux can bork Equinox entirely. Here's how to make sure it doesn't.
You'll need to run this every reboot.
```
# setenforce Permissive
```

## Ubuntu
Run the following command to gather all dependencies needed by Equinox on Ubuntu.
```
# apt-get update && apt-get install clang make gtk4 libgtk-4-dev libadwaita-1 libadwaita-1-dev pcre2 libpcre2-dev glib2.0 libglib2.0-dev libglibutil-dev lxc lxc-templates uidmap lxc-utils bridge-utils dnsmasq
```

Now, unfortunately, just like Fedora, Ubuntu does not have a libgbinder package in its repositories. You'll need to manually clone the repository and compile it instead.
The following one-liner will do it for you:
```
$ git clone https://github.com/mer-hybris/libgbinder.git /tmp/equinox-gbinder && cd /tmp/equinox-gbinder && make -j$(nproc) && sudo make install
```

# Obtaining Nim
Equinox require a Nim version beyond 2.2.2
Run the following one-liner to get Nim and properly install it for your user:
```sh
$ curl https://nim-lang.org/choosenim/init.sh -sSf | sh && echo "PATH=$HOME/.nimble/bin:$PATH" >> ~/.bashrc
```
Note that the second half of this command will add the path to `.bashrc` only.

## Or add nimble to your PATH manually
You can add `:$HOME/.nimble/bin` to your `PATH` export in `.bashrc` or other shell config like the following:
```sh
export PATH="$HOME/.local/bin:$HOME/bin:$HOME/.nimble/bin:$PATH"
```

**Make sure you didn't mess up the config.** Then just reload your `.bashrc` or other shell config.

# Compiling Equinox
After following the above instructions, run:
```
$ nimble install https://github.com/equinoxhq/equinox
```
This will compile Equinox and install it for your user.

# Running Equinox
To run Equinox, run this in your terminal:
```
$ equinox_gui auto
```
This is for the first run. After this, Equinox will create a desktop entry for you that'll let you launch it from your application launcher without the terminal.


