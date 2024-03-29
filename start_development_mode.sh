# This will remove the brew installed chit program for your computer
# Then make new alias, so that the "chit" command will point to the file in this directory
# This makes it easy to blow away whatever you have installed, then immediatley use your computer to actively develop changes and test them in any shell
ln -fs $(pwd)/chit.sh $(which chit)

# We are redirecting to std here
# the script will pause until the user presses
# ENTER (a.k.a. line break) and then execution returns to this file
read -p "Development mode engaged.
Keep this window open until you're done.
Press ENTER when complete." </dev/tty

# At this point, we remove the symlink we made because you're done with dev mode
rm -rf $(which chit)
