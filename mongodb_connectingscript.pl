use MongoDB;
use Data::Dumper;

my $client = MongoDB-> connect();
my $db = $client-> get_database('tutorial');
my $users = $db->get_collection('users');


$users->insert_one({
    "name" => "Suzi",
    "age" => 21,
    "likes" => "dogs"});
#my $likes_dogs = $users->find({"likes" => "dogs"})->fields({"name" => 1});

my $cursor = $users
    ->find({likes => dogs});

    while(my $row = $cursor->next){
    print Dumper $row->{'name'};
}



#
