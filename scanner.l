/* File:  scanner.l
 * ----------------
 * Lex inupt file to generate the scanner for the compiler.
 */

%{

/* The text within this first region delimited by %{ and %} is assumed to
 * be C/C++ code and will be copied verbatim to the lex.yy.c file ahead
 * of the definitions of the yylex() function. Add other header file inclusions
 * or C++ variable declarations/prototypes that are needed by your code here.
 */

#include <string.h>
#include "scanner.h"
#include "utility.h" // for PrintDebug()
#include "errors.h"

/* Global variable: yylval
 * -----------------------
 * This global variable is how we get attribute information about the token
 * just scanned to the client. The scanner sets the global variable
 * appropriately and since it's global the client can just read it.  In the
 * future, this variable will be declared for us in the y.tab.c file
 * produced by Yacc, but for now, we declare it manually.
 */
YYSTYPE yylval;  // manually declared for pp1, later Yacc provides

/* Global variable: yylloc
 * -----------------------
 * This global variable is how we get position information about the token
 * just scanned to the client. (Operates similarly to yylval above)
 */
struct yyltype yylloc; // manually dclared for pp1, later Yacc provides

/* Macro: YY_USER_ACTION 
 * ---------------------
 * This flex built-in macro can be defined to provide an action which is
 * always executed prior to any matched rule's action. Basically, it is
 * a way of having a piece of code common to all actions factored out to
 * this routine.  We already defined it for you and left the empty
 * function DoBeforeEachAction ready for your use as needed. It will
 * be called once for each pattern scanned from the file, before
 * executing its action.
 */
static void DoBeforeEachAction(); 
#define YY_USER_ACTION DoBeforeEachAction();

 int line_no;


%}

 /* The section before the first %% is the Definitions section of the lex
  * input file. Here is where you set options for the scanner, define lex
  * states, and can set up definitions to give names to regular expressions
  * as a simple substitution mechanism that allows for more readable
  * entries in the Rules section later. 
  */

DIGIT             [0-9]
DIGITHEX          [A-Fa-f0-9]
IDENTIFIER        [A-Za-z][A-Za-z0-9_]*


%s comment
%s comment_single_line

%%             /* BEGIN RULES SECTION */
 /* All patterns and actions should be placed between the start and stop
  * %% markers which delimit the Rules section. 
  */ 
<INITIAL>{
void             {return T_Void;}
int              {return T_Int;}
double           {return T_Double;}
bool             {return T_Bool;}
string           {return T_String;}
class            {return T_Class;}
interface        {return T_Interface;}
null             {return T_Null;}
this             {return T_This;}
extends          {return T_Extends;}
implements       {return T_Implements;}
for              {return T_For;}
while            {return T_While;}
if               {return T_If;}
else             {return T_Else;}
return           {return T_Return;}
break            {return T_Break;}
new              {return T_New;}
NewArray         {return T_NewArray;}
Print            {return T_Print;}
ReadInteger      {return T_ReadInteger;}
ReadLine         {return T_ReadLine;}
"<="             {return T_LessEqual;}
">="             {return T_GreaterEqual;}
"!="             {return T_NotEqual;}
"=="             {return T_Equal;}
"&&"             {return T_And;}
"||"             {return T_Or;}
"[]"             {return T_Dims;}

[^\+\-\*/%\<\>=!;,\.\(\)\[\]\|\{\}\"A-Za-z0-9\n\t \r]     {
        ReportError::UnrecogChar(&yylloc, yytext[0]);
}

("+"|"-"|"*"|"/"|"%"|"<"|">"|"="|"!"|";"|","|"."|"("|")"|"["|"]"|"{"|"}")      {return yytext[0];}

[\n\r\t ]          {
        if(yytext[0] == '\n'){
                line_no ++;
                yylloc.last_column = 1;
        }
}

((true)|(false))     {
        if(!strcmp(yytext, "true")){
                yylval.boolConstant = true;
        }else{
                yylval.boolConstant = false;
        }
        return T_BoolConstant;        
}


{DIGIT}+         {
        yylval.integerConstant = atoi(yytext);
        return T_IntConstant;
}

(0[xX]{DIGITHEX}+)  {
        char *end;
        yylval.integerConstant = strtol(yytext, &end,16);
        return T_IntConstant;
}

({DIGIT}+\.{DIGIT}*)([e|E][+|-]?{DIGIT}+)?  {
        yylval.doubleConstant = atof(yytext);
        return T_DoubleConstant;
}

{IDENTIFIER}       {
        if(yyleng > MaxIdentLen){
                strncpy(yylval.identifier, yytext, MaxIdentLen);
                yylval.identifier[MaxIdentLen] = 0;
                /* ERR: identifier too long error */               
                ReportError::LongIdentifier(&yylloc, 
                                            yytext);
        }else{
                strncpy(yylval.identifier, yytext, yyleng);
                yylval.identifier[yyleng] = 0;
        }
        return T_Identifier;
}

\"[^\n\"]*\"        {
        yylval.stringConstant = strdup(yytext);
        yylval.stringConstant[yyleng] = 0;
        return T_StringConstant;
}

\"[^\n\"]*\n        {
        char *report_str = strdup(yytext);
        report_str[yyleng-1] = 0;   /*delete the last \n */
        ReportError::UntermString(&yylloc, report_str);
        free(report_str);
        line_no++;
        yylloc.last_column = 1;
}

"/*"                {
        BEGIN(comment);
}

}

<comment>[^*\n]*    {}
<comment>"*"+[^\*/\n]*     {}
<comment>"\n"       {
        line_no ++; 
        yylloc.last_column = 1;
}
<comment>"*"+"/"    {BEGIN(INITIAL);}

<comment><<EOF>>    {/* ERR: Unterminated comments */
        ReportError::UntermComment();
        yyterminate();
}

"//"                {BEGIN(comment_single_line);}

<comment_single_line>[^\n]+  {}
<comment_single_line>"\n"   {
        BEGIN(INITIAL);
        line_no ++;
        yylloc.last_column = 1;
}
<comment_single_line><<EOF>>    {/* ERR: Unterminated comments */
        ReportError::UntermComment();
        yyterminate();
}


<INITIAL><<EOF>>    {
        yyterminate();
}

%%
/* The closing %% above marks the end of the Rules section and the beginning
 * of the User Subroutines section. All text from here to the end of the
 * file is copied verbatim to the end of the generated lex.yy.c file.
 * This section is where you put definitions of helper functions.
 */


/* Function: InitScanner
 * ---------------------
 * This function will be called before any calls to yylex().  It is designed
 * to give you an opportunity to do anything that must be done to initialize
 * the scanner (set global variables, configure starting state, etc.). One
 * thing it already does for you is assign the value of the global variable
 * yy_flex_debug that controls whether flex prints debugging information
 * about each token and what rule was matched. If set to false, no information
 * is printed. Setting it to true will give you a running trail that might
 * be helpful when debugging your scanner. Please be sure the variable is
 * set to false when submitting your final version.
 */
void InitScanner()
{
    PrintDebug("lex", "Initializing scanner");
    yy_flex_debug = false;
    line_no = 1;  /* initialize the line no. to be 1 */
    yylloc.first_line = 1;
    yylloc.first_column = 1;
    yylloc.last_line = 1;
    yylloc.last_column = 1;
    BEGIN(INITIAL);
}


/* Function: DoBeforeEachAction()
 * ------------------------------
 * This function is installed as the YY_USER_ACTION. This is a place
 * to group code common to all actions.
 */
static void DoBeforeEachAction()
{
        yylloc.first_line = line_no;
        yylloc.last_line = line_no;
        yylloc.first_column = yylloc.last_column;
        yylloc.last_column = yylloc.first_column + yyleng;        
}
