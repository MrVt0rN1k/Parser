#!/usr/bin/perl 
#my $script_path = "/opt/scripts/mr_231";
#my $conf_file = "$script_path/mr_231.conf";
use strict;
use threads;
use IO::File;
use IO::Socket::INET;
my $new_message;

#distanation Hydra(BIP)
my $bip_ip = "127.0.0.1";
my $bip_port = "5559";
my $bip_ident = pack("H*", 'aced000575720000025b42acf317f8060854e00200007870');
my $bip_socket;

#shift counter
my $counter = 0;
my @data = ('responceTime', 'situation', 'id', 'targetNum', 'fixedNum', 'channelId', 'channel', 'rtp', 'radarType', 'radarNum', 'lat', 'lon', 'course', 'speed', 'typeCode', 'type', 'modeCode', 'mode', 'statusCode', 'status', 'msgTime', 'radarTime', 'targetKind', 'removedTargets');
my @values = ('1670944949831', '', '566097', '2', '21', '1', '127.0.0.1:8180', 'Щукинское', 'МР-231', '1', '54.644444444444446', '19.904722222222222', '337.9', '0.1', '0', 'одиночная', '1', 'автосопровождение', '2', 'изменена', '1670944844181', '1670944826000', '0', '[]');
my $len_data = scalar @data;
my @array;
#starting point to start string parsing
my $point_start = 7;
#function for counting and outputting message characters
sub count_sumbol {
    print "$new_message"."\n";
    #repetition cycle
    for(my $y = 0; $y < 20; $y++){
        $counter = 0;
        #shift count cycle
        for(my $i = $point_start; $i < 100; $i++){
            if(substr($new_message, $i, 1) ne ","){
                $counter++;
            }
            elsif(substr($new_message, $i, 1) eq ","){
                $point_start = $i + 1;
                $array[$y] = substr($new_message, $i - $counter, $counter);
                last;
            }
            if(substr($new_message, $i, 1) eq "*"){
                $point_start = $i +1;
                if(substr($new_message, 3, 3) eq "TTM" || substr($new_message, 3, 3) eq "RSD"){
                      $array[$y] = substr($new_message, $point_start - 2, 1);
                }
                for(my $z = 0; $z < 10; $z++){
                    if(substr($new_message, $point_start, $z) eq ""){
                        $array[$y + 1] = substr($new_message, $point_start, $z - 1);
                    }
                }
            }
        }
    }
    $point_start = 7;
}

sub send_to_bip {
    my ($data) = @_;

# print $data."\n";

    #Data preparation
    my $data_size = length($data);
    my $head = pack("N",($data_size+28))."$bip_ident".pack("N",($data_size));
    $data = $head.$data;


    #Open distanation socket
    open_bip_socket();

    #Send data
    eval {
        print $data."\n";
        print $bip_socket $data;
    };

    #Close socket
    eval {
        $bip_socket->close();
    };
}

sub open_bip_socket {
    eval {
            $bip_socket = new IO::Socket::INET (PeerHost => $bip_ip, 
                                                PeerPort => $bip_port, 
                                                Proto => 'tcp') 
            or return 0;
    };

    return 1;
}

while (1) {
    #socket creation
    my $socket = new IO::Socket::INET (LocalPort => 5559, Proto => 'udp');
    #message receipt check
    while ($socket->recv($new_message, 1024)){
        my $json = '';
        #message type is TTM
        if(substr($new_message, 3, 3) eq "TTM"){
            print "Dected TTM\n";
            #parsing data
            count_sumbol();
            #1,2,4,5,7,8      
            $json .=  'radar,127.0.0.1:8180@@'.qq[{].qq["].$data[1].qq["].":".qq[\[].qq[{];
            for(my $i = 2; $i < $len_data - 1; $i++){
                if($i == 22){
                    $json .=  qq["].$data[$i].qq["].":".$values[$i];
                }
                elsif($i == 3){
                    $json .=  qq["].$data[$i].qq["].":".$array[0].",";
                }
                elsif($i == 6 || $i == 7 || $i == 8 || $i == 15 || $i == 19){
                    $json .=  qq["].$data[$i].qq["].":".qq["].$values[$i].qq["].",";
                }
                elsif($i == 12){
                    $json .=  qq["].$data[$i].qq["].":".$array[4].",";
                }
                elsif($i == 13){
                    $json .= qq["].$data[$i].qq["].":".$array[5].",";
                }
                elsif($i == 20 || $i == 21){
                    $json .=  qq["].$data[$i].qq["].":".time()."000,";
                }
                elsif($i == 17){
                    if($array[14] eq "A"){
                         $json .=  qq["].$data[$i].qq["].":".qq["]."автосопровождение".qq["].",";
                    }
                }
                else{
                    $json .=  qq["].$data[$i].qq["].":".$values[$i].",";
                }
            }
            $json .=  qq[}].qq[\]].",";
            $json .=  qq["].$data[0].qq["].":".time()."000,".qq["].$data[23].qq["].":".$values[23].qq[}],"\n";
            send_to_bip($json);
        }
        #message type is VHW
        elsif(substr($new_message, 3, 3) eq "VHW"){
            #print "Dected VHW\n";
            #parsing data
            #count_sumbol();
        }
        #message type is RSD
        elsif(substr($new_message, 3, 3) eq "RSD"){
            #print "Dected RSD\n";
            #parsing data
            #count_sumbol();
        }
        #message type is Unnow
        else{
            print "Unnow message\n";
        }
    }
    #socket closing
    close($socket);
}
