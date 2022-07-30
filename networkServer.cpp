#include <iostream>
#include <fstream>
#include <string>
#include <array>
#include <csignal>
#include <chrono>
#include "percentgraph/percentgraphServer.hpp"

void sigHandler(int signal);
void setupSignals();


using server_t = PercentGraphServer<unsigned long, 3, 2, 2>;
server_t * server_ptr = nullptr;


int main(const int argv, const char * argc[]){

    server_t server("/home/dfuehrer/.cache/dwmblocks/networkpercent/networkpercent", L'b');
    //server.setDelimeters({L'🔽', L'🔼'});
    server.setDelimeters({L'🠗', L'🠕'});
    server_ptr = &server;
    setupSignals();
    // TODO figure out a better way to make a percentage out of bytes probably based on the network cards limits
    constexpr int megabit_rx = 50;
    constexpr int megabit_tx = 10;

    server.runServer([&server] (){
            std::ifstream rx_bytes_f("/sys/class/net/wlan0/statistics/rx_bytes");
            std::ifstream tx_bytes_f("/sys/class/net/wlan0/statistics/tx_bytes");

            server_t::stored_t rx_bytes, tx_bytes;
            rx_bytes_f >> rx_bytes;
            rx_bytes_f.close();
            tx_bytes_f >> tx_bytes;
            tx_bytes_f.close();

            auto [prx_bytes, ptx_bytes, ptime] = server.getDatas();
            //std::array<unsigned long, 2> stored = percentGraph.readDatas();
            //server_t::percent_t rx_percent = (rx_bytes - stored[0]) / megabit_rx / 1000000 * 8;
            //server_t::percent_t tx_percent = (tx_bytes - stored[1]) / megabit_tx / 1000000 * 8;

            //server_t::percent_t rx_percent = (rx_bytes - prx_bytes) / megabit_rx / 1000000 * 8;
            //server_t::percent_t tx_percent = (tx_bytes - ptx_bytes) / megabit_tx / 1000000 * 8;
            server_t::stored_t time = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now().time_since_epoch()).count();

            server_t::stored_t  rx_bits = (rx_bytes - prx_bytes) * 8 * 1000 / (time - ptime);
            server_t::percent_t rx_percent = rx_bits * 100 / megabit_rx / 1000000;
            server_t::stored_t  tx_bits = (tx_bytes - ptx_bytes) * 8 * 1000 / (time - ptime);
            server_t::percent_t tx_percent = tx_bits * 100 / megabit_tx / 1000000;

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
