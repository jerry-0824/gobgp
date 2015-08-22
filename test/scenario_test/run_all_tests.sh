#!/bin/bash
set +e

if [ ! -v GOROOT ]; then
    if which go > /dev/null; then
        GOROOT=`dirname $(dirname $(which go))`
    else
        echo 'set $GOROOT'
        exit 1
    fi
fi

if [ ! -v GOPATH ]; then
    echo 'set $GOPATH'
    exit 1
fi

if [ ! -v GOBGP ]; then
    GOBGP=$GOPATH/src/github.com/osrg/gobgp
fi

if [ ! -v GOBGP_IMAGE ]; then
    GOBGP_IMAGE=gobgp
fi

if [ ! -v WS ]; then
    WS=`pwd`
fi

cd $GOBGP/test/scenario_test

# route server malformed message test
NUM=$(sudo -E python route_server_malformed_test.py -s 2> /dev/null | awk '/invalid/{print $NF}')
PARALLEL_NUM=4
for (( i = 0; i < $(( $NUM / $PARALLEL_NUM + 1)); ++i ))
do
    sudo docker rm -f $(sudo docker ps -a -q)

    PIDS=()
    for (( j = $((PARALLEL_NUM * $i + 1)); j < $((PARALLEL_NUM * ($i+1) + 1)); ++j))
    do
        sudo -E python route_server_malformed_test.py --gobgp-image $GOBGP_IMAGE --test-prefix mal$j --test-index $j -s -x --gobgp-log-level debug --with-xunit --xunit-file=${WS}/nosetest_malform${j}.xml &
        PIDS=("${PIDS[@]}" $!)
        if [ $j -eq $NUM ]; then
            break
        fi
        sleep 4
    done

    for (( j = 0; j < ${#PIDS[@]}; ++j ))
    do
        wait ${PIDS[$j]}
        if [ $? != 0 ]; then
            exit 1
        fi
    done

done

# route server policy test
NUM=$(sudo -E python route_server_policy_test.py -s 2> /dev/null | awk '/invalid/{print $NF}')
PARALLEL_NUM=4
for (( i = 0; i < $(( NUM / PARALLEL_NUM + 1)); ++i ))
do
    sudo docker rm -f $(sudo docker ps -a -q)

    PIDS=()
    for (( j = $((PARALLEL_NUM * $i + 1)); j < $((PARALLEL_NUM * ($i+1) + 1)); ++j))
    do
        sudo -E python route_server_policy_test.py --gobgp-image $GOBGP_IMAGE --test-prefix p$j --test-index $j -s -x --gobgp-log-level debug --with-xunit --xunit-file=${WS}/nosetest_policy${j}.xml &
        PIDS=("${PIDS[@]}" $!)
        if [ $j -eq $NUM ]; then
            break
        fi
        sleep 4
    done

    for (( j = 0; j < ${#PIDS[@]}; ++j ))
    do
        wait ${PIDS[$j]}
        if [ $? != 0 ]; then
            exit 1
        fi
    done

done

PIDS=()

# route server test
sudo -E python route_server_test.py --gobgp-image $GOBGP_IMAGE --test-prefix rs -s -x --with-xunit --xunit-file=${WS}/nosetest.xml &
PIDS=("${PIDS[@]}" $!)

# route server ipv4 ipv6 test
sudo -E python route_server_ipv4_v6_test.py --gobgp-image $GOBGP_IMAGE --test-prefix v6 -s -x --with-xunit --xunit-file=${WS}/nosetest_ip.xml &
PIDS=("${PIDS[@]}" $!)

# bgp router test
sudo -E python bgp_router_test.py --gobgp-image $GOBGP_IMAGE --test-prefix bgp -s -x --with-xunit --xunit-file=${WS}/nosetest_bgp.xml &
PIDS=("${PIDS[@]}" $!)

# ibgp router test
sudo -E python ibgp_router_test.py --gobgp-image $GOBGP_IMAGE --test-prefix ibgp -s -x --with-xunit --xunit-file=${WS}/nosetest_ibgp.xml &
PIDS=("${PIDS[@]}" $!)

# evpn router test
sudo -E python evpn_test.py --gobgp-image $GOBGP_IMAGE --test-prefix evpn -s -x --with-xunit --xunit-file=${WS}/nosetest_evpn.xml &
PIDS=("${PIDS[@]}" $!)

# flowspec test
sudo -E python flow_spec_test.py --gobgp-image $GOBGP_IMAGE --test-prefix flow -s -x --with-xunit --xunit-file=${WS}/nosetest_flow.xml &
PIDS=("${PIDS[@]}" $!)

for (( i = 0; i < ${#PIDS[@]}; ++i ))
do
    wait ${PIDS[$i]}
    if [ $? != 0 ]; then
        exit 1
    fi
done

echo 'all tests passed successfully'
exit 0
