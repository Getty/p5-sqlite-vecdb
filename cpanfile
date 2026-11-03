requires 'Alien::sqlite_vec';
requires 'Carp';
requires 'DBD::SQLite', '1.70';
requires 'DBI';
requires 'JSON::MaybeXS';
requires 'Moose';
suggests 'Langertha', '0.200';

on test => sub {
    requires 'Test2::V0';
};
