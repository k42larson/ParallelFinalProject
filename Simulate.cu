#include <stdio.h>
#include <curand.h>
#include <curand_kernel.h>

//number of total simulations
#define N   200000

__global__ void add( int *GoingWon, int *NotGoingWon, unsigned int seed ) {
	//get the id of the block
	int tid = blockIdx.x;

	//initalize random number generator
	curandState_t state;
	curand_init(seed, tid, 0, &state);

	//the initial score of the game
	//team 1 is user's team, team 2 is the opponent
	int team1Score = 17;
	int team2Score = 10;

	//current position of the ball on the field
	//in terms of yards from your endzone
	double position = 50;

	//current down(always starts at 4)
	int down = 4;

	//yardToGet to get first down
	//in terms of yards from your endzone
	double yardToGet = 55;

	//current quarter and seconds left in the quarter
	//(5 for ot)
	int quarter = 4;
	int secondsLeft = 400;

	//Did user's team get the ball first?
	bool team1BallFirst = true;
	
	
	//offense and defense information
	//league average is approximately 5.6
	double averageYardsTeam1 = 5.6;
	double averageYardsTeam2 = 5.6;
	double averageYardsGivenTeam1 = 5.6;
	double averageYardsGivenTeam2 = 5.6;

	//variable to keep track of team in possesion of the ball
	bool team1HasBall = true;

	//variable to keep track of the game ending	
	bool gameOver = false;
	
	//variable to keep track of the simulated play length
	double playLength = 0;
	
	//variable to figure out whether this simulation
	//will be going for it or not
	int whichScenario = tid % 2;
	
	//variable to keep track if this is the first play
	//of the simulation
	bool isFirstPlay = true;

	//the simulated game loop
	while(!gameOver)
	{
		//since the simulation defaults to not going
		//for it on 4th down, we must override on the
		//first play
		if(down < 4 || (isFirstPlay && whichScenario == 0))
		{
			//this if statement generates the amount of yards gained 
			//on the play using a random number between 0 and 1
			double x = curand_uniform(&state);
			if(x <= .2)
			{
				playLength = 22.36 * sqrt(x) - 10;
			}
			else if(x <= .8)
			{
				playLength = 14.3 * x - 2.86;
			}
			else
			{
				playLength =  300 * (x - .7) * (x - .7) + 5.86;
			}
			
			//determine who has the ball before determining the effects of the play
			//team 1 has ball
			if(team1HasBall)
			{
				
				//adjust based on the team 1's offense and team 2's defense
				playLength += averageYardsTeam1 + averageYardsGivenTeam2 - 11.2;
				
				//update position
				position += playLength;
				//if touchdown
				if(position >= 100)
			        {
					team1Score += 7;
					team1HasBall = false;
					//for simplicity's sake kickoffs will always be touchbacks
					position = 75;
					yardToGet = 65;
					down = 1;
					//this if statement is to check for ot
					//and end it since any score ends ot
					if(quarter > 4)
						gameOver = true;
			        }
				//failed to get first down
				else if(position < yardToGet)
					down++;
				//saftey
				else if(position <= 0)
				{
					team2Score += 2;
					team1HasBall = false;
					position = 75;
					yardToGet = 65;
					down = 1;
					if(quarter > 4)
						gameOver = true;
				}
				//first down
				else
				{
					yardToGet = position + 10;
					//check for first and goal
					if(yardToGet > 100)
					{
						yardToGet = 100;
					}
					down = 1;
				}
			}
			else
			//team 2 has ball
			{
				//adjust based on the team 2's offense and team 1's defense
				playLength += averageYardsTeam2 + averageYardsGivenTeam1 - 11.2;
				//update position
				position -= playLength;

				//if touchdown
				if(position <= 0)
				{
					team2Score += 7;
					team1HasBall = true;
					position = 25;
					yardToGet = 35;
					down = 1;
					if(quarter > 4)
						gameOver = true;
				}
				//safety
				else if(position >= 100)
				{
					team1Score += 2;
					team1HasBall = true;
					position = 25;
					yardToGet = 35;
					down = 1;
					if(quarter > 4)
						gameOver = true;
				}
				//failed to get first down
				else if(position > yardToGet)
					down++;
				//first down
				else
				{
					yardToGet = position - 10;
					//first and goal
					if(yardToGet < 0)
					{
						yardToGet = 0;
					}
					down = 1;
				}
			}
		}
		//failed 4th down conversion
		else if(down >= 5)
		{
			if(team1HasBall)
			{
				yardToGet = position - 10;
				down = 1;
				team1HasBall = false;
			}
			else
			{
				yardToGet = position + 10;
				down = 1;
				team1HasBall = true;
			}
		}
		//it is typical a 4th down
		else
		{
			//team 1 has ball
			if(team1HasBall)
			{
				//out of field goal range
				if(position < 65)
				{
					//the average net punt is roughly 40 yards
					position += 40;
					//check for touchback
					if(position >= 100)
					{
						position = 75;
					}
				}
				else
				{
					//generate random number to see if field goal
					double y = curand_uniform(&state);
					//odds of making a field goal roughly correlates with
					// 1 percentage point per yard away from the end zone
					if(y < position/100.0)
					{
						team1Score += 3;
						position = 75;
						if(quarter > 4)
							gameOver = true;
					}
					//if the field goal is missed the position doesn't 
					//change unless the team is inside the 25
					//then it acts like a touchback
					else if(position > 75)
					{
						position = 75;
					}
				}
				//update the first down line, down and possesion
				yardToGet = position - 10;
				down = 1;
				team1HasBall = false;
			}
			//team 2 has ball
			else
			{
				//out of field goal range
				if(position > 35)
				{	
					//the average net punt is roughly 40 yards
					position -= 40;
					//check for touchback
					if(position <= 0)
					{
						position = 25;
					}
				}
				else
				{
					//generate random number to see if field goal
					double y = curand_uniform(&state);
					//odds of making a field goal roughly correlates with
					// 1 percentage point per yard away from the end zone
					if(y < (100-position)/100.0)
					{
						team2Score += 3;
						position = 25;
						if(quarter > 4)
							gameOver = true;
					}
					//if the field goal is missed the position doesn't 
					//change unless the team is inside the 25
					//then it acts like a touchback
					else if(position < 25)
					{
						position = 25;
					}
				}
				//update the first down line, down and possesion
				yardToGet = position + 10;
				down = 1;
				team1HasBall = true;
			}
		}
		//each play takes about 25 seconds
		//because there are roughly 150 plays per game 
		secondsLeft -= 20;
		//end of the quarter 
		if(secondsLeft <= 0)
		{
			quarter++;
			//check to see if the game ended
			if(quarter >= 5 && team1Score != team2Score)
			{
				gameOver = true;
			}
			//end of the half
			if(quarter == 3)
			{
				//figure out who which team got the ball first
				if(team1BallFirst)
				{
					position = 75;
					yardToGet = 65;
					down = 1;
					team1HasBall = false;
				}
				else
				{
					position = 25;
					yardToGet = 35;
					down = 1;
					team1HasBall = true;
				}
				secondsLeft = 900;
			}
			//reset the quarter countdown
			else
			{
				secondsLeft = 900;
			}
		}
		//no longer first play
		isFirstPlay = false;
		/*if(tid == 68)
		{
			printf("%d %d\n", team1Score, team2Score);
			printf("%f %d %f\n", position, down, yardToGet);
			printf("%d %d\n\n", quarter, secondsLeft);
		}*/
	}
	if(team1Score > team2Score)
	{
		if(whichScenario == 0)
			GoingWon[tid] = 1;
		else
			NotGoingWon[tid] = 1;
	}
}

int main( void ) {
    	int GoingWon[N], NotGoingWon[N];
    	int *dev_a, *dev_b ;
	

    	// allocate the memory on the GPU
    	cudaMalloc( (void**)&dev_a, N * sizeof(int) );
    	cudaMalloc( (void**)&dev_b, N * sizeof(int) );


    	// fill the arrays 'a' and 'b' on the CPU
    	for (int i=0; i<N; i++) {
        	GoingWon[i] = 0;
        	NotGoingWon[i] = 0;
   	}

    	// copy the arrays 'a' and 'b' to the GPU
    	cudaMemcpy( dev_a, GoingWon, N * sizeof(int),
                              cudaMemcpyHostToDevice );
    	cudaMemcpy( dev_b, NotGoingWon, N * sizeof(int),
                              cudaMemcpyHostToDevice );

    	add<<<N,1>>>( dev_a, dev_b, time(NULL) );

    	// copy the array 'c' back from the GPU to the CPU
    	cudaMemcpy( GoingWon, dev_a, N * sizeof(int),
                              cudaMemcpyDeviceToHost );

	cudaMemcpy( NotGoingWon, dev_b, N * sizeof(int),
                              cudaMemcpyDeviceToHost );

    	// calculate the results
	int totGoingWon = 0;
	int totNotGoingWon = 0;
    	for (int i=0; i<N; i++) {
        	totGoingWon += GoingWon[i];
		totNotGoingWon += NotGoingWon[i];
    	}
	printf("How often you won going for it: %f%%\nHow often you won not going for it: %f%%\n", 200.0*totGoingWon/N, 200.0*totNotGoingWon/N);

    	// free the memory allocated on the GPU
    	cudaFree( dev_a ) ;
    	cudaFree( dev_b ) ;

    	return 0;
}