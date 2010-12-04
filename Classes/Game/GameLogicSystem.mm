/*
 *  GameLogicSystem.cpp
 *  ComponentV3
 *
 *  Created by jrk on 10/11/10.
 *  Copyright 2010 flux forge. All rights reserved.
 *
 */

#include "ComponentV3.h"
#include "InputDevice.h"
#include "ActionSystem.h"

#include "GameLogicSystem.h"
#include "Texture2D.h"
#include "SoundSystem.h"
#include "globals.h"

#include "Component.h"
#include "GameComponents.h"

namespace game 
{


	GameLogicSystem::GameLogicSystem (EntityManager *entityManager)
	{
		_entityManager = entityManager;
		marked_color = -1;
		head_row = -1;
		head_col = -1;
		num_of_marks = 0;
		
		memset (markers, 0x00, MAX_MARKERS * sizeof(Entity*));
		marker_index = 0;
		
	}
	
	void GameLogicSystem::remove_chain ()
	{
		std::vector<Entity*> entities;
		_entityManager->getEntitiesPossessingComponents(entities, GameBoardElement::COMPONENT_ID, Position::COMPONENT_ID, ARGLIST_END );
		std::vector<Entity*>::const_iterator it = entities.begin();
		
		Entity *current_entity = NULL;
		GameBoardElement *current_gbe = NULL;
		while (it != entities.end())
		{
			current_entity = *it;
			++it;
			current_gbe = _entityManager->getComponent <GameBoardElement> (current_entity);
			
			if (current_gbe->marked)
			{
				if (num_of_marks >= 2)
				{
					_entityManager->addComponent <MarkOfDeath> (current_entity);
					
					ParticleSystem::createParticleEmitter ("goldstar2.pex", 0.25 , 
														   vector2D_make(current_gbe->col * TILESIZE_X + BOARD_X_OFFSET, current_gbe->row*TILESIZE_Y+BOARD_Y_OFFSET));
				}
				current_gbe->marked = false;
			}
		}
	}
	
	
	void GameLogicSystem::handle_chain ()
	{
		//score if the chain had 2 or more entries
		if (num_of_marks >= 2)
		{
			int score = (num_of_marks * 15) * num_of_marks;
			float num = num_of_marks;
			float time_add = ((float)(num*0.20*num*0.20));		//0.25
			
			//only add time for chain if we're playinh (not game over)
			if (g_GameState.game_state == GAME_STATE_PLAY && g_GameState.next_state == GAME_STATE_PLAY)
			{
				g_GameState.time_left += time_add;
			}
			g_GameState.score += score;
			g_GameState.killed_last_frame = num_of_marks;
//			
			int sfx = (num_of_marks-2);
			sfx += SFX_FRUIT_REMOVE_2;
			
			sfx = std::min(SFX_FRUIT_REMOVE_6, sfx);
//			if (sfx > SFX_FRUIT_REMOVE_6)
//				sfx = SFX_FRUIT_REMOVE_6;
			
			//printf("sfx: %i\n", sfx);
			
			SoundSystem::make_new_sound (sfx);
			int bonus = 0;
			if (g_GameState.previous_kill >= 3 && num_of_marks >= 4)
			{	
				sfx = SFX_GOOD;
				bonus = 250 * num_of_marks;
				
				if (g_GameState.previous_kill >= 4 && num_of_marks >= 5)
				{	
					sfx = SFX_EXCELLENT;
					bonus = 350 * num_of_marks;
				}
				
				if (g_GameState.previous_kill >= 5 && num_of_marks >= 6)
				{	
					sfx = SFX_INCREDIBLE;
					bonus = 600 * num_of_marks;
				}
				
				
				SoundSystem::make_new_sound (sfx);	
			}
			g_GameState.score += bonus;
			g_GameState.time_left += bonus/1000.0;
			printf("Bonus: %i\n", bonus);

			printf("time add: %f\n", time_add);
			printf("Bonus time: %f\n",bonus/1000.0);
			printf("sum t: %f\n", time_add + (bonus/1000.0));
			g_GameState.previous_kill = num_of_marks;
		}

		//g_GameState.previous_kill = num_of_marks;
		
		//remove the markers
		for (int i = 0; i < MAX_MARKERS; i++)
		{
			Entity *e = markers[i];
			if (e)
			{
				markers[i] = NULL;
				PEmitter *pe = _entityManager->getComponent <PEmitter> (e);
				[pe->pe->pe setDuration: 0.1];
			}
		}		
		
		remove_chain ();
		
		marker_index = 0;
		num_of_marks = 0;
	}
	
	void GameLogicSystem::mark_chain ()
	{
		vector2D v = InputDevice::sharedInstance()->touchLocation();
		int col = (v.x - BOARD_X_OFFSET + TILESIZE_X/2) / TILESIZE_X;
		int row = (v.y - BOARD_Y_OFFSET + TILESIZE_Y/2) / TILESIZE_Y;
		
		std::vector<Entity*> entities;
		_entityManager->getEntitiesPossessingComponents(entities, GameBoardElement::COMPONENT_ID, Position::COMPONENT_ID, ARGLIST_END );
		std::vector<Entity*>::const_iterator it = entities.begin();
		
		Entity *current_entity = NULL;
		GameBoardElement *current_gbe = NULL;
		while (it != entities.end())
		{
			current_entity = *it;
			++it;
			current_gbe = _entityManager->getComponent <GameBoardElement> (current_entity);

			if (!current_gbe->marked)
			{
				if ((current_gbe->col == col) && (current_gbe->row == row))
				{	
					if (marked_color == -1)
						marked_color = current_gbe->type;
					if (head_col == -1 || head_row == -1)
					{
						head_row = current_gbe->row;
						head_col = current_gbe->col;
					}
					
					if (current_gbe->type == marked_color)
					{	
						int diff = 0;
						
						diff = ( abs (current_gbe->row - head_row) + 
								abs (current_gbe->col - head_col));
						
						if (diff <= 1)
						{	
							num_of_marks ++;
							current_gbe->marked = true;
							head_col = current_gbe->col;
							head_row = current_gbe->row;
							
							if (marker_index < MAX_MARKERS)
							{
								Entity *pe = ParticleSystem::createParticleEmitter ("marker.pex", -1.0 , vector2D_make(col * TILESIZE_X + BOARD_X_OFFSET, row*TILESIZE_Y+BOARD_Y_OFFSET));
								
								markers[marker_index++] = pe;
							}
						}
					}
				}
			}
		}
	}

	void GameLogicSystem::update (float delta)
	{
		_delta = delta;
		g_GameState.killed_last_frame = 0;
		
		bool touch = InputDevice::sharedInstance()->isTouchActive();
		if (touch)
		{
			mark_chain();
		}
		else 
		{
			marked_color = -1;
			head_row = -1;
			head_col = -1;
		}
		
		if (InputDevice::sharedInstance()->touchUpReceived())
		{
			handle_chain();
		}
	}
}