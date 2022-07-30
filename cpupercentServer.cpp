#include <iostream>
#include <fstream>
#include <string>
#include <array>
#include <csignal>
#include "percentgraph/percentgraphServer.hpp"

void sigHandler(int signal);
void setupSignals();


using server_t = PercentGraphServer<unsigned long, (16 + 1) * 2, 16, 1>;
server_t * server_ptr = nullptr;


int main(const int argv, const char * argc[]){

    server_t server("/home/dfuehrer/.cache/dwmblocks/cpupercent/cpupercent");
    server_ptr = &server;
    setupSignals();

    server.runServer([&server] (){
            std::ifstream statFile("/proc/stat");
            std::string cpu;
            std::array<server_t::stored_t, (server_t::numGraphPercents + server_t::numPrintPercents) * 2> saves;
            std::array<server_t::percent_t, server_t::numGraphPercents> percents;

            server_t::stored_t  user,   nice,   system,   idle,   iowait,   irq,   softirq,   steal,   tmp1,   tmp2;
            //statFile >> cpu >>  user >> nice >> system >> idle >> iowait >> irq >> softirq >> steal >> tmp1 >> tmp2;

            //server_t::percent_t active = user + system + nice + softirq + steal;
            //server_t::percent_t total  = active + idle + iowait;

            //saves = server.getDatas();

            //server_t::percent_t percent;
            //if(total == saves[1]){
            //    percent = 0;
            //}else{
            //    percent = ((active - saves[0]) * 100) / (total - saves[1]);
            //}
            //saves[0] = active;
            //saves[1] = total;

            saves = server.getDatas();

            server_t::percent_t percent;
            for(int i = 0; i < server_t::numGraphPercents + server_t::numPrintPercents; ++i){
            //for(int i = 0; i < 1; ++i){
                statFile >> cpu >>  user >> nice >> system >> idle >> iowait >> irq >> softirq >> steal >> tmp1 >> tmp2;

                server_t::stored_t active = user + system + nice + softirq + steal;
                server_t::stored_t total  = active + idle + iowait;

                server_t::percent_t tmpPercent;
                if(total == saves[i * 2 + 1]){
                    tmpPercent = 0;
                }else{
                    tmpPercent = ((active - saves[i * 2]) * 100) / (total - saves[i * 2 + 1]);
                }
                //std::cerr << cpu << ": " << tmpPercent << ", " << active - saves[i * 2] << " " << total - saves[i * 2 + 1] << std::endl;
                if(i){
                    percents[i - 1] = tmpPercent;
                }else{
                    percent = tmpPercent;
                }
                saves[i * 2]     = active;
                saves[i * 2 + 1] = total;

            }

            statFile.close();

            server.setPercents(percents, percent);
            server.saveDatas(saves);

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
