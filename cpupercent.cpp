#include <iostream>
#include <fstream>
#include <string>
#include <array>
#include "../percentgraph/percentgraph.hpp"



int main(const int argv, const char * argc[]){

    std::ifstream statFile("/proc/stat");
    std::string cpu;

    unsigned long      user,   nice,   system,   idle,   iowait,   irq,   softirq,   steal;
    statFile >> cpu >> user >> nice >> system >> idle >> iowait >> irq >> softirq >> steal;
    statFile.close();

    unsigned long active = user + system + nice + softirq + steal;
    unsigned long total  = active + idle + iowait;

    PercentGraph<unsigned long, 2, 1> percentGraph("/home/dfuehrer/.cache/dwmblocks/cpupercent/cpupercent2.txt");
    //std::array<unsigned long, 2> stored = percentGraph.readDatas();
    //unsigned long percent = (active - stored[0]) * 100 / (total - stored[1]);
    auto [pactive, ptotal] = percentGraph.readDatas();
    unsigned long percent = ((active - pactive) * 100) / (total - ptotal);
    percentGraph.outputPercents(percent);
    percentGraph.saveDatas({active, total});

    return 0;
}

