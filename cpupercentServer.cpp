#include <iostream>
#include <fstream>
#include <string>
#include <array>
#include <csignal>
#include "../percentgraph/percentgraphServer.hpp"

void sigHandler(int signal);
void setupSignals();


using server_t = PercentGraphServer<unsigned long, 2, 1>;
server_t * server_ptr = nullptr;


int main(const int argv, const char * argc[]){

    server_t server("/home/dfuehrer/.cache/dwmblocks/cpupercent/cpupercent");
    server_ptr = &server;
    setupSignals();

    server.runServer([&server] (){
            std::ifstream statFile("/proc/stat");
            std::string cpu;

            unsigned long      user,   nice,   system,   idle,   iowait,   irq,   softirq,   steal;
            statFile >> cpu >> user >> nice >> system >> idle >> iowait >> irq >> softirq >> steal;
            statFile.close();

            unsigned long active = user + system + nice + softirq + steal;
            unsigned long total  = active + idle + iowait;

            auto [pactive, ptotal] = server.getDatas();
            //std::array<unsigned long, 2> stored = percentGraph.readDatas();
            //unsigned long percent = (active - stored[0]) * 100 / (total - stored[1]);
            server_t::percent_t percent = ((active - pactive) * 100) / (total - ptotal);

            server.getPercents(percent);
            server.saveDatas({active, total});

            });

    server_ptr = nullptr;

    return 0;
}

void sigHandler(int signal){
    if(server_ptr != nullptr){
        server_ptr->stopRunning();
        server_ptr->cleanup();
    }
    // if this didnt work to kill things then it will at least remove the handler so next time the kill will succeed (ungracefully)
    std::signal(signal, SIG_DFL);
}


// set up handling for these normal signals, others will kill ungracefully
void setupSignals(){
    std::signal(SIGHUP,  sigHandler);
    std::signal(SIGTERM, sigHandler);
    std::signal(SIGINT,  sigHandler);
}
