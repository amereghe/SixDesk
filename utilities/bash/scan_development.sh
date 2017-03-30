
function how_to_use() {
    cat <<EOF
   `basename $0` [action] [option]

    actions
    -e      replace all echos by sixdeskmess

EOF
}




function replace_echo(){
    $1 | sed 'g/echo /sixdeskmess=' 

}
