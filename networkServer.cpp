#include <iostream>
#include <fstream>
#include <string>
#include <array>
#include <csignal>
#include <chrono>
#include "percentgraph/percentgraphServer.hpp"

void sigHandler(int signal);
void setupSignals();


using server_t = PercentGraphServer<unsigned long long, 3, 2, 2>;
server_t * server_ptr = nullptr;


int main(const int argv, const char * argc[]){

    std::string cacheDir = getCacheDir("dwmblocks/networkpercent");
    server_t server(cacheDir + "/networkpercent", L'b');
    //server.setDelimeters({L'🔽', L'🔼'});
    server.setDelimeters({L'🠗', L'🠕'});
    server_ptr = &server;
    setupSignals();
    // TODO figure out a better way to make a percentage out of bytes probably based on the network cards limits (/sys/class/net/*device*/speed)
    constexpr int megabit_rx = 50;
    constexpr int megabit_tx = 15;
    constexpr int ms2s       = 1000;
    constexpr int mega       = 1000000;

    server.runServer([&server] (){
            server_t::stored_t rx_bytes, tx_bytes, tmp;

            // TODO make this more dynamic than this
            std::ifstream rx_bytes_wifi_f ("/sys/class/net/wlan0/statistics/rx_bytes");

            rx_bytes_wifi_f >> rx_bytes;
            rx_bytes_wifi_f.close();
            std::ifstream tx_bytes_wifi_f ("/sys/class/net/wlan0/statistics/tx_bytes");
            tx_bytes_wifi_f >> tx_bytes;
            tx_bytes_wifi_f.close();
            std::ifstream rx_bytes_ether_f("/sys/class/net/enp6s0/statistics/rx_bytes");
            rx_bytes_ether_f >> tmp;
            rx_bytes_ether_f.close();
            rx_bytes += tmp;
            std::ifstream tx_bytes_ether_f("/sys/class/net/enp6s0/statistics/tx_bytes");
            tx_bytes_ether_f >> tmp;
            tx_bytes_ether_f.close();
            tx_bytes += tmp;

            auto [prx_bytes, ptx_bytes, ptime] = server.getDatas();
            // this is an ugly line
            server_t::stored_t time = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now().time_since_epoch()).count();

            server_t::stored_t  rx_bits    = (rx_bytes - prx_bytes) * 8 * ms2s / (time - ptime);
            server_t::percent_t rx_percent = rx_bits * 100 / megabit_rx / mega;
            server_t::stored_t  tx_bits    = (tx_bytes - ptx_bytes) * 8 * ms2s / (time - ptime);
            server_t::percent_t tx_percent = tx_bits * 100 / megabit_tx / mega;

            //std::cerr << rx_bytes << ' ' << prx_bytes << ' ' << time << ' ' << ptime << '\n';
            //std::cerr << rx_percent << '\n';

            // give it the percents to graph and the network speeds to display
            server.setPercents({rx_percent, tx_percent}, {rx_bits, tx_bits});
            server.saveDatas({rx_bytes, tx_bytes, time});

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
