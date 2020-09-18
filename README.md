# What is it?
This script automatically enters the times you tracked with Timewarrior into Beeminder.

# Usage
In `settings.sh`, enter what tags you want to report to Beeminder, your authentication token and your username.
The script assumes that your Beeminder goals are named the same as the tags you use for tracking.
Now you should be able to start `./main.sh` which will report the times every 60 seconds.

