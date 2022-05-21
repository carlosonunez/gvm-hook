# gvm-hook

Works with [gvm](https://github.com/moovweb/gvm) to enable per-project Go installations, just like `rvm`

## Why use this?

- You want to explicitly declare which version of Golang your project uses
  in your repo
- You want `gvm` to do the thing automatically when you `cd` into your project
- You want `gvm` to pick a default Go when you're not inside of your project

## How to use

Add this to your `.bash_profile`:

```sh
if test -d "$HOME/.config/gvm-hook"
then
  mkdir -p "$HOME/.config/gvm-hook"
  git clone https://github.com/carlosonunez/gvm-hook "$HOME/.config/gvm-hook"
fi
source "$HOME/.config/gvm-hook/gvm_hook.bash"
```

Then for each project you want `gvm-hook` to work in, add a `.gvm_local`
file that looks like this:

```sh
PROJECT_NAME=sample-project
gvm install go1.18 --name="${PROJECT_NAME}-go1.18" 
gvm use "${PROJECT_NAME}-go1.18"
```

> You can also name this file '.go_version' if you want something closer to
> RVM's `.ruby_version`.

Whenever you `cd` into the directory, it will use that GVM-managed Go
version:

```
$: cd ../sample-project/
Already installed!
Now using version sample-project-go1.18
```

This works even if you're in subdirectories of that project:

```
$: cd some/subdirectory/of/thing && gvm list

gvm gos (installed)

=> sample-project-go1.16
   go1.17.1
   status-go1.17.5
   system
```

`gvm-hook` resets to your default GVM version once you exit your repo's context:

```
$: cd ..
Now using version go1.17.1
```
