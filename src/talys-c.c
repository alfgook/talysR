#include <stdio.h>
#include <unistd.h> 
#include <limits.h>

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

   // Preserve original file descriptor for stdout.
   int old_stdout = dup(1);

   // redirect the stdout to file
   if(!freopen("output","a+",stdout)) {
      fprintf( stderr, "talys-c: couldn't open the output file\n");
      return;
   }

   // run the talys calculation
   machine_();
   constants_();
   talysinput_();
   talysinitial_();
   talysreaction_();
   if(input1l_.flagnatural) natural_();

   // redirect the stdout back to screen
   FILE *fp = fdopen(old_stdout, "w");

   // close the output file
   fclose(stdout);

   stdout = fp;

   // change back into the original workdir
   if(chdir(cwd)) {
      fprintf( stderr, "talys-c: couldn't change back to original directory\n");
      return;
   }

   return;
}