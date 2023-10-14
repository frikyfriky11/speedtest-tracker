FROM ubuntu:latest

# install curl to download the install script
# and jq to parse the speedtest results as json
RUN apt update && apt install -y curl jq 

# install the ookla speedtest cli
RUN curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash
RUN apt install speedtest

# copy the program
COPY ./speedtest.sh .

# set the program as the start script
CMD ["./speedtest.sh"]
