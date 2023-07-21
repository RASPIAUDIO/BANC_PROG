#!/bin/bash

# Déclaration pour le bouton
echo "23" > /sys/class/gpio/export
echo "in" > /sys/class/gpio/gpio23/direction

# Déclaration pour la LED
echo "25" > /sys/class/gpio/export
echo "out" > /sys/class/gpio/gpio25/direction

flite "Push to start"

no_usb_found=false

# Define an array with the ttyUSB ports
esp_ports=("/dev/ttyUSB0" "/dev/ttyUSB1" "/dev/ttyUSB2" "/dev/ttyUSB3" "/dev/ttyUSB4" "/dev/ttyUSB5" "/dev/ttyUSB6" "/dev/ttyUSB7")

while true;
do
    cat /sys/class/gpio/gpio23/value | while read line
    do 
        if echo "$line" | grep -q "0"; then
            echo "Button pushed"
            flite "... Downloading"
            declare -A pids
            led_blinking=false

            for port in "${esp_ports[@]}"
            do
                if [ -e $port ]; then # check if port exists
                    echo "$port exist"
                    sleep 2
                    esptool --port $port -b 1152000 write_flash 0x0 /home/rosco/prog/luxe_bluetooth.bin |tee /home/rosco/prog/esptool_output_${port##*/}.txt &
                    pids[$port]=$!
                    
                    echo $no_usb_found
                    no_usb_found=false

               fi
            done

            if [ ${#pids[@]} -eq 0 ]; then
                echo "no usb found"
                 flite "No USB found"
                if [ "$no_usb_found" = true ]; then
                    flite "No USB found2"
                    echo "no usb found2"
                    no_usb_found=true
                fi
            fi
                    
             

            for port in "${!pids[@]}"
            do
                esptool_pid=${pids[$port]}
                while kill -0 $esptool_pid > /dev/null 2>&1; do
                    if grep -q "Writing" /home/rosco/prog/esptool_output_${port##*/}.txt && ! $led_blinking; then
                        # Start blinking LED
                        while kill -0 $esptool_pid > /dev/null 2>&1; do
                            echo "1" > /sys/class/gpio/gpio25/value
                            sleep 0.5
                            echo "0" > /sys/class/gpio/gpio25/value
                            sleep 0.5
                        done &
                        led_blinking=true
                    fi
                    sleep 0.1
                done

                # Turn off LED
                echo "0" > /sys/class/gpio/gpio25/value
                led_blinking=false
                wait $esptool_pid
                esptool_status=$?

                port_name=$(echo $port | sed 's/\/dev\/ttyUSB/USB/g')

                if grep -q "Leaving..." /home/rosco/prog/esptool_output_${port##*/}.txt && ! $led_blinking; then
                    echo "Success on $port_name"
                    echo "1" > /sys/class/gpio/gpio25/value
                    flite "It's a SUCCESS  on $port_name" 
                    rm /home/rosco/prog/esptool_output_${port##*/}.txt
                else
                    echo "Failed on $port_name"
                    echo "0" > /sys/class/gpio/gpio25/value
                    flite "It's a FAIL on $port_name"
                fi
                
                
            done
            
                        
          #  for i in /sys/bus/pci/drivers/[uoex]hci_hcd/*:*; do
           #   echo "${i##*/}" > "${i%/*}/unbind"
            #  echo "${i##*/}" > "${i%/*}/bind"
            #done
        fi 
    done
done
