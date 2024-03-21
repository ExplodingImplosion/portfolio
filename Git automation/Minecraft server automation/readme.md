File that I created to 'automatically' back up my brother's minecraft server he asked me to host. For several months it ran from my brother's PC as a crash-proof auto-saving server that could support 10-20 players concurrently without issue. Automatically starts the server with 4 gigabytes of dedicated memory, and automatically uploads changes to the server's world file to the GitHub repo when the server stops. Afterwards, it restarts the server.

TODO:
1.  Forcibly restart the server at specific times of day OR after 12 hours of activity.
2.  Currently all GitHub commits are labeled as %datenow%. It's a functionally useless issue as all commits are timestamped, but it looks crummy.e
