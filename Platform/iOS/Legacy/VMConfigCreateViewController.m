//
// Copyright © 2019 osy. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "VMConfigCreateViewController.h"
#import "UTMConfiguration.h"
#import "VMConfigTextField.h"

@interface VMConfigCreateViewController ()

@end

@implementation VMConfigCreateViewController {
    BOOL _advancedConfiguration;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.advancedConfiguration = NO;
    self.saveButton.enabled = self.configuration.name.length > 0;
}

#pragma mark - Properties

- (BOOL)advancedConfiguration {
    return _advancedConfiguration;
}

- (void)setAdvancedConfiguration:(BOOL)advancedConfiguration {
    _advancedConfiguration = advancedConfiguration;
    if (advancedConfiguration) {
        self.advancedConfigurationCell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        self.advancedConfigurationCell.accessoryType = UITableViewCellAccessoryNone;
    }
}

#pragma mark - Table delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([tableView cellForRowAtIndexPath:indexPath] == self.advancedConfigurationCell) {
        self.advancedConfiguration = !self.advancedConfiguration;
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    } else {
        [super tableView:tableView didSelectRowAtIndexPath:indexPath];
    }
}

#pragma mark - Event handlers

- (IBAction)savePressed:(UIBarButtonItem *)sender {
    [self.view endEditing:YES];
    if (self.advancedConfiguration) {
        [self performSegueWithIdentifier:@"createVMToConfiguration" sender:sender];
    } else {
        [self performSegueWithIdentifier:@"createVMDone" sender:sender];
    }
}

- (IBAction)cancelPressed:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)configTextEditChanged:(VMConfigTextField *)sender {
    [super configTextEditChanged:sender];
    if (sender == self.nameField) {
        // TODO: input validation
        self.saveButton.enabled = sender.text.length > 0;
        self.configuration.name = sender.text;
    }
}

@end
