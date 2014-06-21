//
//  ViewController.m
//  Anybody here?
//
//  Created by Паша on 19.06.14.
//  Copyright (c) 2014 svatorus. All rights reserved.
//

#import "ViewController.h"
#import "Reachability.h"

@interface ViewController () <UITableViewDataSource, UITableViewDelegate>

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    //если подключение к интернету есть - получаем данные о текущем состоянии пользователя
    
    if ([self checkInternetConnection]) {
        [self checkStatus];
    }
    
    //иначе - выводим сообщение об ошибке и ставим счетчик на 0
    
    else {
        [self setButtonParametrs:NO];
        [_timeLabel setText:@"0:00:00"];
    }
    
    
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*Изменяем статус пользователя, хранящийся в isOnline на противоположный.*/

- (IBAction)changeStatusAction:(id)sender {
    
    //проверяем наличие интернет - соединения
    
    if ([self checkInternetConnection]) {
        [self sendStatusToCloud:!_isOnline];
    }
    
    //при отсутствии выводим сообщение об ошибке
    else {
        [self showAlertView];
    }
    
    
}

/*Проверяем статус пользователя при запуске программы */

- (void) checkStatus {
    
    [self setActivityStatus:YES]; //Показываем индикатор активности и затемнение
    
    PFQuery *query = [PFQuery queryWithClassName:@"usersArray"];
    
    [query whereKey:@"UUID" equalTo:[OpenUDID value]];
    
    //получаем массив объектов с облака где поле UDID равно UDID девайса
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        
        
        //если массив не пуст то приложение уже было запущено на этом устройстве. Тогда получаем необходимые данные
        if ([objects count]==1) {
            if (!error) { //если нет ошибки то получаем статус пользователя и ID объекта в таблице
                
                for (PFObject *object in objects) {
                    _isOnline = [[[object objectForKey:@"isOnline"] objectAtIndex:0] boolValue];
                    _objectID = [object objectId];
                }
            } else {
                
                //в противном случае выводим в лог ошибку
                NSLog(@"Error: %@ %@", error, [error userInfo]);
            }
            
            //задаем параметры кнопки исходя из статуса
            [self setButtonParametrs:_isOnline];
            
            //если статус Онлайн то проверяем сколько времени осталось до окончания оного и создаем локальное уведомление + запускаем таймер
            if (_isOnline) {
                NSDate *updateTime = [[objects objectAtIndex:0] updatedAt];
                
                NSDate *now = [NSDate date];
                
                if ([now timeIntervalSince1970]<([updateTime timeIntervalSince1970]+3600)) {
                    
                    _time = [NSNumber numberWithInt:(int)([updateTime timeIntervalSince1970]+3600)-[now timeIntervalSince1970]];
                    
                    [self implementNotificationWithTime:[_time floatValue]];
                    
                    [self setTimerStatus:YES];
                }
                
                else {
                    [self sendStatusToCloud:NO];
                }
                
                //получаем список пользователей в сети
                
                [self getOnlineUsersList];
            }
            
            else {
                
                //если статус оффлайн то указываем время до окончания равное 0 и скрываем индикатор активности и затемнение
                [_timeLabel setText:@"0:00:00"];
                [self setActivityStatus:NO];
            }
            
            
        }
        
        //в противном случае определяем статус как оффлайн
        else {
            _isOnline = NO;
            [_timeLabel setText:@"0:00:00"];
            _time = [NSNumber numberWithInt:0];
            [self setButtonParametrs:NO];
        }
        
    }];
}

/*Отправляем статус в облако*/

- (void) sendStatusToCloud:   (BOOL) status {
    
    [self setActivityStatus:YES]; //показываем индикатор активности и затемнение
    
    [self sendPushNotificationToOtherDevicesWithKey:status]; //отправляем пуш уведомление о смене статуса другим пользлвателям
    
    //если объект с нашим UDID уже есть в облаке то переписываем его
    if (_objectID) {
        PFQuery *query = [PFQuery queryWithClassName:@"usersArray"];
        
        [query getObjectInBackgroundWithId:_objectID block:^(PFObject *user, NSError *error) {

            [user setObject:[NSArray arrayWithObject:[NSNumber numberWithBool:status]] forKey:@"isOnline"];
            
            [user saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
                
                
                if (succeeded) {

                    if (status) {
                        _isOnline = YES;
                        _time = [NSNumber numberWithInt:3600];
                        [self implementNotificationWithTime:3600.0f];
                        [self setTimerStatus: YES];
                        [self getOnlineUsersList];
                    }
                    
                    else {
                        _isOnline = NO;
                        _time = [NSNumber numberWithInt:0];
                        [_onlineUsersArray removeAllObjects];
                        [self setDataToTableView:_onlineUsersArray];
                        [self cancelNotification];
                        [self setTimerStatus: NO];
                        [_timeLabel setText:@"0:00:00"];
                    }
                    
                    [self setButtonParametrs:status];
                }
                
                else {
                    NSLog(@"%@", error);
                    [self showAlertView];
                }
                
            }];

            
        }];
        
        
    }
    
    else {
    
    //иначе создаем новый
    PFObject *user = [PFObject objectWithClassName:@"usersArray"];
    [user setObject:[NSArray arrayWithObject:[OpenUDID value]] forKey:@"UUID"];
    [user setObject:[NSArray arrayWithObject:[NSNumber numberWithBool:status]] forKey:@"isOnline"];
    
    [user saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
        
        
        if (succeeded) {
            
            if (status) {
                _objectID = user.objectId;
                _isOnline = YES;
                _time = [NSNumber numberWithInt:3600];
                [self implementNotificationWithTime:3600.0f];
                [self setTimerStatus:YES];
                [self getOnlineUsersList];
            }
            
            else {
                _objectID = user.objectId;
                _isOnline = NO;
                _time = [NSNumber numberWithInt:0];
                [_onlineUsersArray removeAllObjects];
                [self setDataToTableView:_onlineUsersArray];
                [self cancelNotification];
                [self setTimerStatus: NO];
                [_timeLabel setText:@"0:00:00"];
            }

            
            [self setButtonParametrs:status];
        }
        
        else {
            [self showAlertView];
        }
        
        [self setActivityStatus:NO];
    }];
    
    }
    
    
    
}

/*Определяем параметры кнопки (цвет, заголовок)*/

- (void) setButtonParametrs: (BOOL) status {
    
    //если статус Онлайн - кнопка зеленая с надписью Выйти
    if (status) {
        [_onlineButton setBackgroundColor:[UIColor greenColor]];
        [_onlineButton setTitle:@"Выйти" forState:UIControlStateNormal];
    }
    
    //в противном случае - красная с надписью Войти
    else {
        [_onlineButton setBackgroundColor:[UIColor redColor]];
        [_onlineButton setTitle:@"Войти" forState:UIControlStateNormal];
    }
    
    [self setActivityStatus:NO]; //скрываем индикатор активности и затемнение
}

/*В зависимости от принимаемого значения определяем показывать ли индикатор активности и затемнение*/

- (void) setActivityStatus:  (BOOL) status {
    if (status) {
        [_hiddenImage setHidden:NO];
        [_activityIndicator startAnimating];
    }
    
    else {
        [_hiddenImage setHidden:YES];
        [_activityIndicator stopAnimating];
    }
}

/*Показать предупреждение об ошибке*/

- (void) showAlertView {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Ошибка!" message:@"Что то пошло не так, попробуйте позже" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
    [alert show];
}

/*Заполнить таблицу согласно входящему массиву*/

- (void) setDataToTableView: (NSArray *) array {
    
    NSMutableArray *idArray = [[NSMutableArray alloc] init]; //создаем новый массив

    //выбираем из входящего массива только UDID и добавляем их в только что созданный массив
    for (int i=0; i<[array count]; i++) {
        [idArray addObject:[[array objectAtIndex:i] objectForKey:@"UUID"]];
    }
    
    _onlineUsersArray = [NSMutableArray arrayWithArray:idArray];
    
    [_tableView reloadData];
    
    [self setActivityStatus:NO];
}

/*Получить список пользователей в статусе Онлайн*/

- (void) getOnlineUsersList {
    
    PFQuery *query = [PFQuery queryWithClassName:@"usersArray"];
    [query whereKey:@"isOnline" equalTo:[NSNumber numberWithBool:YES]]; //задаем параметры где статус isOnline должен быть равен YES
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) { //выполняем поиск

        if (error==nil) { //если все хорошо то добавляем отправляем полученный массив в функцию, заполняющую таблицу
            [self setDataToTableView:objects];
        }
        else {
            
            //в противном случае выводим сообщение об ошибке
            [self setActivityStatus:NO];
            [self showAlertView];
            
        }
        
        
    }];

}

/*Создать локальное уведомление, которое будет показано через время, указанное в time*/

- (void) implementNotificationWithTime: (float) time {
    
    //создаем локальное уведомление, задаем его параметры и добавляем его в цетр уведомлений
    _notification = [UILocalNotification new];
    _notification.timeZone  = [NSTimeZone systemTimeZone];
    _notification.fireDate  = [[NSDate date] dateByAddingTimeInterval:time];
    _notification.alertAction = @"Внимание!";
    _notification.alertBody = @"Вы покинули статус Онлайн";
    _notification.soundName = UILocalNotificationDefaultSoundName;
    [[UIApplication sharedApplication] scheduleLocalNotification:_notification];
}

 /*Удалить уведомление из центра уведомлений*/

- (void) cancelNotification {
    
     [[UIApplication sharedApplication] cancelLocalNotification:_notification];
    
}

/*Запустить\остановить таймер изменяющий оставшееся время до конца статуса онлайн*/

- (void) setTimerStatus: (BOOL) status {
    
    if (status) {
        _timer = [NSTimer scheduledTimerWithTimeInterval:1.0f
                                                  target:self
                                                selector:@selector(changeTimeLeft)
                                                userInfo:nil
                                                 repeats:YES];
    }
    
    else {
        if ([_timer isValid]) {
            [_timer invalidate];
        }
        
        _timer = nil;
    }
        
    
    
}

/*Измнить время, оставшееся до истечения статуса Онлайн и отобразить его в timeLabel*/

- (void) changeTimeLeft {
    
    _time = [NSNumber numberWithInt:[_time intValue]-1];
    
    if ([_time intValue]<=0) {
        [self setTimerStatus:NO];
        [self sendStatusToCloud:NO];
        [_timeLabel setText:@"0:00:00"];
    }
    
    else {
    
        int hour = [_time intValue]/3600;
    
        int min = ([_time intValue]-hour*3600)/60;
    
        int sec = ([_time intValue] - min*60 - hour*3600);
    
        NSString *timeLeft = [NSString stringWithFormat:@"%@:%@:%@", [self fixTime:hour], [self fixTime:min], [self fixTime:sec]];
    
        [_timeLabel setText:timeLeft];
        
        [self getOnlineUsersList];
    
    }
    
}


/*Функция исправляет вид отображения минут\секунд. (преобразует вид 12:3 в 12:03)*/

- (NSString *) fixTime: (int) time {

    if (time<10) {
        return [NSString stringWithFormat:@"0%i", time];
    }
    
    else
        return [NSString stringWithFormat:@"%i", time];
}

/*Отправляет всем девайсам пуш уведомление с номером своего UDID и уточнением своего статуса (вышел\зашел)*/

- (void) sendPushNotificationToOtherDevicesWithKey: (BOOL) key {
    
    PFQuery *pushQuery = [PFInstallation query];
    [pushQuery whereKey:@"deviceType" equalTo:@"ios"];
    if (key) {

        [PFPush sendPushMessageToQueryInBackground:pushQuery
                                       withMessage:[NSString stringWithFormat:@"Пользователь %@ зашел в сеть", [OpenUDID value]]];
    }
    
    else {
        [PFPush sendPushMessageToQueryInBackground:pushQuery
                                       withMessage:[NSString stringWithFormat:@"Пользователь %@ вышел из сети", [OpenUDID value]]];
    }
}

/*Определение количества ячеек в таблице*/

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_onlineUsersArray count];
}

/*Возвращаем ячейку*/

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    
    [cell.textLabel setFont:[[cell.textLabel font] fontWithSize:12]];
    
    [cell.textLabel setText:[[_onlineUsersArray objectAtIndex:indexPath.row] objectAtIndex:0]];
    
    return cell;
}

/*Проверка наличия интернет подключения*/

- (BOOL) checkInternetConnection {
    Reachability *networkReachability = [Reachability reachabilityForInternetConnection];
    NetworkStatus networkStatus = [networkReachability currentReachabilityStatus];
    if (networkStatus == NotReachable) {
        return NO;
    } else
        return YES;
}

@end
