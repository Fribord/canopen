# CANopen object defintion file format

## Declarations

### Define a module

    {module, atom()}.

### Define collection of objecs

    {definitions, atom()}.

### Set object(s) version

    {version, version()}.

### Define a number of objects

    {version,module(),version(),[ objdef() ]}.

### Include types and objects

    {require, atom()}.

### Define an object or a structure defintion
	 
    {objdef, index:16, [option()]}.
    {objdef, {from:16, to:16 [,step:16]}, [option()]}.

### Define enumerated data

    {enum, id(), [{atom(), value()}]}.

## Defintions

    option() ::
           {id, atom()}             -- required
         | {name, string()}
         | {struct,object_type()}   -- required
         | {catecory,catrgory()}
         | {type, type()}           -- required if struct=var | optional
         | {access, access()}
         | {entry,subindex:8,[entry()]}
         | {entry,{from:8,to:8},[entry()]}
	 
    entry() ::
          {id, atom()}
        | {name, string()}         -- required
        | {pdo,pdo_mapping()}
        | {type, type()}           -- required
        | {access, access()}
        | {range, number()|string()|{number(),number()}}
        | {default,number()|string()}
        | {substitute, number()|string()}

    version() :: "yyyy-mm-dd[Thh-mm-ss]"

    object_type() :: var | rec | array | defstruct 

    category() :: *optional | mandatory | conditional

    access()   :: *ro | rw | wo | c

    signed_type() ::
              integer8 | integer16 | integer24 | integer32 | 
              integer40 | integer48 | integer56 | integer64

    unsigned_type() ::
              unsigned8 | unsigned16 | unsigned24 | unsigned32 |
              unsigned40 | unsigned48 | unsigned56 | unsigned64

    integer_type() ::
              signed_type() | unsigned_type()

    real_type() ::
              real32 | float | real64 | double | 

    number_type() ::
             integer_typ() | real_type()

    type() :: boolean | number_type() |  visible_string |
             string | octet_string unicode_string | time_of_day |
             time_difference | bit_string | domain | 
             pdo_parameter | pdo_mapping | sdo_parameter | identity |
             {enum, integer_type(), <id>} |
             {enum, integer_type(), [{<atom>, <value>}]} |
             {bitfield, integer_type(), <id>} |
             {bitfield, integer_type(), [{<atom>, <value>}]}

    pdo_mapping() :: *no | optional | default
