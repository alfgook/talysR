#include <stdio.h>
#include <unistd.h> 
#include <limits.h>
#include <fcntl.h>

extern void machine_();
extern void constants_();
extern void talysinput_();
extern void talysinitial_();
extern void talysreaction_();
extern void natural_();

extern struct {
   int flaginitpop,flagnatural,flagmicro,flagastro,flagbest,flagbestbr,flagbestend;
} input1l_;

void talys(char **directory)
{
   
   char cwd[PATH_MAX];

   // get the current workdir for reference
   if(getcwd(cwd, sizeof(cwd))==NULL) {
      fprintf( stderr, "talys-c: couldn't determine the current directory\n");
      return;
   }

   // change into the requested talys calculation directory
   if(chdir(directory[0])) {
      fprintf( stderr, "talys-c: couldn't change directory to: %s \n", directory[0]);
      return;
   }

   // check that there is an input file in the directory
   if(access("input", F_OK)) {
      fprintf( stderr, "talys-c: couldn't find the input file in %s \n", directory[0]);
      chdir(cwd);
      return;
   }

   // copy the stdout filedescriptor
   int out = dup(STDOUT_FILENO);

   // close stdout
   close(STDOUT_FILENO);

   // open a file where talys can write its stdout
   int log = open("output", O_WRONLY | O_CREAT, S_IRUSR | S_IWUSR);
   if(log != STDOUT_FILENO) {
      fprintf(stderr, "could not create talys output file");
   }

   // run the talys calculation
   machine_();
   constants_();
   talysinput_();
   talysinitial_();
   talysreaction_();
   if(input1l_.flagnatural) natural_();

   //flush stdout to make sure nothing is left in the buffer
   fflush(stdout);
   // get back stdout
   dup2(out, STDOUT_FILENO);

   // change back into the original workdir
   if(chdir(cwd)) {
      fprintf( stderr, "talys-c: couldn't change back to original directory\n");
      return;
   }

   return;
}