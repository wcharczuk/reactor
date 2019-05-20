# reactor
A reactor simulator. Completely useless. Only for fun.

# installation

```bash
> go get github.com/wcharczuk/reactor
```

That's it. I'm not going to distribute prebuilt binaries, just install it with golang yourself.

# usage

type `help` into the command prompt to get a list of commands.

# cool things to highlight

by default, the reactor simulator ships with some scripts that help batch commands together. these commands can be used to scram the reactor or put it in a decent baseline state.

you can add more yourself by pointing the binary at a config file and specifying a yaml map `script_name` to []string for each of the script lines.

