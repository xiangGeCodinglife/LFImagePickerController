//
//  LFPhotoPreviewController.m
//  LFImagePickerController
//
//  Created by LamTsanFeng on 2017/2/13.
//  Copyright © 2017年 LamTsanFeng. All rights reserved.
//

#import "LFPhotoPreviewController.h"
#import "LFImagePickerController.h"
#import "LFImagePickerHeader.h"
#import "UIView+LFFrame.h"
#import "UIView+LFAnimate.h"
#import "LFPhotoPreviewCell.h"
#import "LFAssetManager.h"

typedef NS_ENUM(NSUInteger, LFEditPhotoType) {
    /** 绘画 */
    LFEditPhotoType_draw = 0,
    /** 贴图 */
    LFEditPhotoType_sticker,
    /** 文本 */
    LFEditPhotoType_text,
    /** 模糊 */
    LFEditPhotoType_splash,
    /** 修剪 */
    LFEditPhotoType_crop,
};

@interface LFPhotoPreviewController () <UICollectionViewDataSource,UICollectionViewDelegate,UIScrollViewDelegate>
{
    UICollectionView *_collectionView;
    
    UIView *_naviBar;
    UIButton *_backButton;
    UIButton *_selectButton;
    
    UIView *_toolBar;
    UIButton *_doneButton;
    UIImageView *_numberImageView;
    UILabel *_numberLabel;
    UIButton *_originalPhotoButton;
    UILabel *_originalPhotoLabel;
    UIButton *_editButton;
    
    /** 编辑模式 */
    UIView *_edit_naviBar;
    UIView *_edit_toolBar;
}

@property (nonatomic, strong) NSMutableArray <LFAsset *>*models;                  ///< All photo models / 所有图片模型数组
@property (nonatomic, assign) NSInteger currentIndex;           ///< Index of the photo user click / 用户点击的图片的索引

@property (nonatomic, assign) BOOL isPreviewPhoto;

@property (nonatomic, assign) BOOL isHideNaviBar;

@property (nonatomic, assign) double progress;
@end

@implementation LFPhotoPreviewController

- (instancetype)initWithModels:(NSArray <LFAsset *>*)models index:(NSInteger)index excludeVideo:(BOOL)excludeVideo
{
    self = [super init];
    if (self) {
        if (models) {
            _models = [NSMutableArray arrayWithArray:models];
            _currentIndex = index;
            if (excludeVideo) {
                NSMutableArray *models = [_models mutableCopy];
                /** 移除视频对象 */
                for (NSInteger i = 0; i<models.count; i++) {
                    LFAsset *model = models[i];
                    if (model.type == LFAssetMediaTypeVideo) {
                        [models removeObjectAtIndex:i];
                        if (index > i) {
                            index--;
                        }
                        i--;
                    }
                }
                _currentIndex = index;
                _models = models;
            }
        }
    }
    return self;
}
- (instancetype)initWithPhotos:(NSArray <UIImage *>*)photos index:(NSInteger)index
{
    self = [super init];
    if (self) {
        if (photos) {
            _models = [@[] mutableCopy];
            _currentIndex = index;
            for (UIImage *image in photos) {
                LFAsset *model = [[LFAsset alloc] initWithAsset:nil type:LFAssetMediaTypePhoto];
                model.previewImage = image;
                [_models addObject:model];
            }
        }
        _isPreviewPhoto = YES;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self configCollectionView];
    [self configCustomNaviBar];
    [self configBottomToolBar];
    
    if (self.photoEditting) { /** 开启编辑模式 */
        [self editButtonClick];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES];
    if (iOS7Later) [UIApplication sharedApplication].statusBarHidden = YES;
    if (_currentIndex) [_collectionView setContentOffset:CGPointMake((self.view.width + 20) * _currentIndex, 0) animated:NO];
    [self refreshNaviBarAndBottomBarState];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO];
    if (iOS7Later) [UIApplication sharedApplication].statusBarHidden = NO;
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)configCustomNaviBar {
    LFImagePickerController *imagePickerVc = (LFImagePickerController *)self.navigationController;
    
    _naviBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.width, 64)];
    _naviBar.backgroundColor = [UIColor colorWithRed:(34/255.0) green:(34/255.0)  blue:(34/255.0) alpha:0.7];
    
    _backButton = [[UIButton alloc] initWithFrame:CGRectMake(10, 10, 44, 44)];
    [_backButton setImage:bundleImageNamed(@"navi_back.png") forState:UIControlStateNormal];
    [_backButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_backButton addTarget:self action:@selector(backButtonClick) forControlEvents:UIControlEventTouchUpInside];
    
    if (!_isPreviewPhoto) { /** 非图片预览模式 */
        _selectButton = [[UIButton alloc] initWithFrame:CGRectMake(self.view.width - 54, 10, 42, 42)];
        [_selectButton setImage:bundleImageNamed(imagePickerVc.photoDefImageName) forState:UIControlStateNormal];
        [_selectButton setImage:bundleImageNamed(imagePickerVc.photoSelImageName) forState:UIControlStateSelected];
        [_selectButton addTarget:self action:@selector(select:) forControlEvents:UIControlEventTouchUpInside];
        [_naviBar addSubview:_selectButton];
    }
    
    [_naviBar addSubview:_backButton];
    [self.view addSubview:_naviBar];
}

- (void)configBottomToolBar {
    _toolBar = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.height - 44, self.view.width, 44)];
    static CGFloat rgb = 34 / 255.0;
    _toolBar.backgroundColor = [UIColor colorWithRed:rgb green:rgb blue:rgb alpha:0.7];
    
    LFImagePickerController *imagePickerVc = (LFImagePickerController *)self.navigationController;
    
    CGFloat editWidth = [imagePickerVc.editBtnTitleStr boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX) options:NSStringDrawingUsesFontLeading attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:15]} context:nil].size.width;
    _editButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _editButton.frame = CGRectMake(10, 0, editWidth, 44);
    _editButton.titleLabel.font = [UIFont systemFontOfSize:15];
    [_editButton addTarget:self action:@selector(editButtonClick) forControlEvents:UIControlEventTouchUpInside];
    [_editButton setTitle:imagePickerVc.editBtnTitleStr forState:UIControlStateNormal];
    [_editButton setTitleColor:[UIColor colorWithWhite:0.8f alpha:1.f] forState:UIControlStateNormal];
    
    if (imagePickerVc.allowPickingOriginalPhoto) {
        CGFloat fullImageWidth = [imagePickerVc.fullImageBtnTitleStr boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX) options:NSStringDrawingUsesFontLeading attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:13]} context:nil].size.width;
        _originalPhotoButton = [UIButton buttonWithType:UIButtonTypeCustom];
        CGFloat width = fullImageWidth + 56;
        _originalPhotoButton.frame = CGRectMake((CGRectGetWidth(_toolBar.frame)-width)/2-fullImageWidth/2, 0, width, 44);
        _originalPhotoButton.imageEdgeInsets = UIEdgeInsetsMake(0, -10, 0, 0);
        _originalPhotoButton.backgroundColor = [UIColor clearColor];
        [_originalPhotoButton addTarget:self action:@selector(originalPhotoButtonClick) forControlEvents:UIControlEventTouchUpInside];
        _originalPhotoButton.titleLabel.font = [UIFont systemFontOfSize:13];
        [_originalPhotoButton setTitle:imagePickerVc.fullImageBtnTitleStr forState:UIControlStateNormal];
        [_originalPhotoButton setTitle:imagePickerVc.fullImageBtnTitleStr forState:UIControlStateSelected];
        [_originalPhotoButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [_originalPhotoButton setTitleColor:[UIColor whiteColor] forState:UIControlStateSelected];
        [_originalPhotoButton setImage:bundleImageNamed(imagePickerVc.photoPreviewOriginDefImageName) forState:UIControlStateNormal];
        [_originalPhotoButton setImage:bundleImageNamed(imagePickerVc.photoOriginSelImageName) forState:UIControlStateSelected];
        
        _originalPhotoLabel = [[UILabel alloc] init];
        _originalPhotoLabel.frame = CGRectMake(fullImageWidth + 42, 0, 80, 44);
        _originalPhotoLabel.textAlignment = NSTextAlignmentLeft;
        _originalPhotoLabel.font = [UIFont systemFontOfSize:13];
        _originalPhotoLabel.textColor = [UIColor whiteColor];
        _originalPhotoLabel.backgroundColor = [UIColor clearColor];
        if (imagePickerVc.isSelectOriginalPhoto) [self showPhotoBytes];
    }
    
    _doneButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _doneButton.frame = CGRectMake(self.view.width - 44 - 12, 0, 44, 44);
    _doneButton.titleLabel.font = [UIFont systemFontOfSize:15];
    [_doneButton addTarget:self action:@selector(doneButtonClick) forControlEvents:UIControlEventTouchUpInside];
    [_doneButton setTitle:imagePickerVc.doneBtnTitleStr forState:UIControlStateNormal];
    [_doneButton setTitleColor:imagePickerVc.oKButtonTitleColorNormal forState:UIControlStateNormal];
    
    _numberImageView = [[UIImageView alloc] initWithImage:bundleImageNamed(imagePickerVc.photoNumberIconImageName)];
    _numberImageView.backgroundColor = [UIColor clearColor];
    _numberImageView.frame = CGRectMake(self.view.width - 56 - 28, 7, 30, 30);
    _numberImageView.hidden = imagePickerVc.selectedModels.count <= 0;
    
    _numberLabel = [[UILabel alloc] init];
    _numberLabel.frame = _numberImageView.frame;
    _numberLabel.font = [UIFont systemFontOfSize:15];
    _numberLabel.textColor = [UIColor whiteColor];
    _numberLabel.textAlignment = NSTextAlignmentCenter;
    _numberLabel.text = [NSString stringWithFormat:@"%zd",imagePickerVc.selectedModels.count];
    _numberLabel.hidden = imagePickerVc.selectedModels.count <= 0;
    _numberLabel.backgroundColor = [UIColor clearColor];
    
    [_originalPhotoButton addSubview:_originalPhotoLabel];
    [_toolBar addSubview:_editButton];
    [_toolBar addSubview:_originalPhotoButton];
    [_toolBar addSubview:_doneButton];
    [_toolBar addSubview:_numberImageView];
    [_toolBar addSubview:_numberLabel];
    [self.view addSubview:_toolBar];
}

- (void)configCollectionView {
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.itemSize = CGSizeMake(self.view.width + 20, self.view.height);
    layout.minimumInteritemSpacing = 0;
    layout.minimumLineSpacing = 0;
    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(-10, 0, self.view.width + 20, self.view.height) collectionViewLayout:layout];
    _collectionView.backgroundColor = [UIColor blackColor];
    _collectionView.dataSource = self;
    _collectionView.delegate = self;
    _collectionView.pagingEnabled = YES;
    _collectionView.scrollsToTop = NO;
    _collectionView.showsHorizontalScrollIndicator = NO;
    _collectionView.contentOffset = CGPointMake(0, 0);
    _collectionView.contentSize = CGSizeMake(_models.count * (self.view.width + 20), 0);
    [self.view addSubview:_collectionView];
    [_collectionView registerClass:[LFPhotoPreviewCell class] forCellWithReuseIdentifier:@"LFPhotoPreviewCell"];
}

#pragma mark - Click Event

- (void)select:(UIButton *)selectButton {
    LFImagePickerController *imagePickerVc = (LFImagePickerController *)self.navigationController;
    LFAsset *model = _models[_currentIndex];
    if (!selectButton.isSelected) {
        // 1. select:check if over the maxImagesCount / 选择照片,检查是否超过了最大个数的限制
        if (imagePickerVc.selectedModels.count >= imagePickerVc.maxImagesCount) {
            NSString *title = [NSString stringWithFormat:@"你最多只能选择%zd张照片", imagePickerVc.maxImagesCount];
            [imagePickerVc showAlertWithTitle:title];
            return;
            // 2. if not over the maxImagesCount / 如果没有超过最大个数限制
        } else {
            [imagePickerVc.selectedModels addObject:model];
        }
    } else {
        NSArray *selectedModels = [NSArray arrayWithArray:imagePickerVc.selectedModels];
        for (LFAsset *model_item in selectedModels) {
            if ([[[LFAssetManager manager] getAssetIdentifier:model.asset] isEqualToString:[[LFAssetManager manager] getAssetIdentifier:model_item.asset]]) {
                // 1.6.7版本更新:防止有多个一样的model,一次性被移除了
                NSArray *selectedModelsTmp = [NSArray arrayWithArray:imagePickerVc.selectedModels];
                for (NSInteger i = 0; i < selectedModelsTmp.count; i++) {
                    LFAsset *model = selectedModelsTmp[i];
                    if ([model isEqual:model_item]) {
                        [imagePickerVc.selectedModels removeObjectAtIndex:i];
                        break;
                    }
                }
                break;
            }
        }
    }
    model.isSelected = !selectButton.isSelected;
    [self refreshNaviBarAndBottomBarState];
    if (model.isSelected) {
        [UIView showOscillatoryAnimationWithLayer:selectButton.imageView.layer type:OscillatoryAnimationToBigger];
    }
    [UIView showOscillatoryAnimationWithLayer:_numberImageView.layer type:OscillatoryAnimationToSmaller];
}

- (void)backButtonClick {
    if (self.navigationController.childViewControllers.count < 2) {
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
    if (self.backButtonClickBlock) {
        self.backButtonClickBlock();
    }
}

- (void)doneButtonClick {
    LFImagePickerController *imagePickerVc = (LFImagePickerController *)self.navigationController;
    // 如果图片正在从iCloud同步中,提醒用户
    if (_progress > 0 && _progress < 1) {
        [imagePickerVc showAlertWithTitle:@"正在从iCloud同步照片"]; return;
    }
    // 如果没有选中过照片 点击确定时选中当前预览的照片
    if (imagePickerVc.selectedModels.count == 0 && imagePickerVc.minImagesCount <= 0) {
        LFAsset *model = _models[_currentIndex];
        [imagePickerVc.selectedModels addObject:model];
    }
    
    if (imagePickerVc.minImagesCount && imagePickerVc.selectedModels.count < imagePickerVc.minImagesCount) {
        NSString *title = [NSString stringWithFormat:@"请至少选择%zd张照片", imagePickerVc.minImagesCount];
        [imagePickerVc showAlertWithTitle:title];
        return;
    }

    if (self.doneButtonClickBlock) {
        self.doneButtonClickBlock();
    }
}

- (void)editButtonClick {
    [_naviBar removeFromSuperview];
    [self.view addSubview:self.edit_naviBar];
    
    [_toolBar removeFromSuperview];
    [self.view addSubview:self.edit_toolBar];
}

- (void)originalPhotoButtonClick {
    _originalPhotoButton.selected = !_originalPhotoButton.isSelected;
    LFImagePickerController *imagePickerVc = (LFImagePickerController *)self.navigationController;
    imagePickerVc.isSelectOriginalPhoto = _originalPhotoButton.isSelected;
    _originalPhotoLabel.hidden = !_originalPhotoButton.isSelected;
    if (imagePickerVc.isSelectOriginalPhoto) {
        [self showPhotoBytes];
        if (!_selectButton.isSelected) {
            // 如果当前已选择照片张数 < 最大可选张数 && 最大可选张数大于1，就选中该张图
            LFImagePickerController *imagePickerVc = (LFImagePickerController *)self.navigationController;
            if (imagePickerVc.selectedModels.count < imagePickerVc.maxImagesCount) {
                [self select:_selectButton];
            }
        }
    }
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat offSetWidth = scrollView.contentOffset.x;
    offSetWidth = offSetWidth +  ((self.view.width + 20) * 0.5);
    
    NSInteger currentIndex = offSetWidth / (self.view.width + 20);
    
    if (currentIndex < _models.count && _currentIndex != currentIndex) {
        _currentIndex = currentIndex;
        [self refreshNaviBarAndBottomBarState];
    }
}

#pragma mark - UICollectionViewDataSource && Delegate

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return _models.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    LFPhotoPreviewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"LFPhotoPreviewCell" forIndexPath:indexPath];
    cell.model = _models[indexPath.row];
    __weak typeof(self) weakSelf = self;
    if (!cell.singleTapGestureBlock) {
        __weak typeof(_naviBar) weakNaviBar = _naviBar;
        __weak typeof(_toolBar) weakToolBar = _toolBar;
        __weak typeof(_edit_naviBar) weakEditNaviBar = self.edit_naviBar;
        __weak typeof(_edit_toolBar) weakEditToolBar = self.edit_toolBar;
        cell.singleTapGestureBlock = ^(){
            // show or hide naviBar / 显示或隐藏导航栏
            weakSelf.isHideNaviBar = !weakSelf.isHideNaviBar;
            weakNaviBar.hidden = weakSelf.isHideNaviBar;
            weakToolBar.hidden = weakSelf.isHideNaviBar;
            weakEditNaviBar.hidden = weakSelf.isHideNaviBar;
            weakEditToolBar.hidden = weakSelf.isHideNaviBar;
        };
    }
    [cell setImageProgressUpdateBlock:^(double progress) {
        weakSelf.progress = progress;
    }];
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    if ([cell isKindOfClass:[LFPhotoPreviewCell class]]) {
        [(LFPhotoPreviewCell *)cell recoverSubviews];
    }
}

- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    if ([cell isKindOfClass:[LFPhotoPreviewCell class]]) {
        [(LFPhotoPreviewCell *)cell recoverSubviews];
    }
}

#pragma mark - Private Method

- (void)refreshNaviBarAndBottomBarState {
    LFImagePickerController *imagePickerVc = (LFImagePickerController *)self.navigationController;
    LFAsset *model = _models[_currentIndex];
    _selectButton.selected = model.isSelected;
    _numberLabel.text = [NSString stringWithFormat:@"%zd",imagePickerVc.selectedModels.count];
    _numberImageView.hidden = (imagePickerVc.selectedModels.count <= 0 || _isHideNaviBar);
    _numberLabel.hidden = (imagePickerVc.selectedModels.count <= 0 || _isHideNaviBar);
    
    _originalPhotoButton.selected = imagePickerVc.isSelectOriginalPhoto;
    _originalPhotoLabel.hidden = !_originalPhotoButton.isSelected;
    if (imagePickerVc.isSelectOriginalPhoto) [self showPhotoBytes];
    
    // If is previewing video, hide original photo button
    // 如果正在预览的是视频，隐藏原图按钮
    if (!_isHideNaviBar) {
        if (model.type == LFAssetMediaTypeVideo) {
            _originalPhotoButton.hidden = YES;
            _originalPhotoLabel.hidden = YES;
        } else {
            _originalPhotoButton.hidden = NO;
            if (imagePickerVc.isSelectOriginalPhoto)  _originalPhotoLabel.hidden = NO;
        }
    }
    
    _doneButton.hidden = NO;
    
    // 让宽度/高度小于 最小可选照片尺寸 的图片不能选中
    if (![[LFAssetManager manager] isPhotoSelectableWithAsset:model.asset]) {
        _numberLabel.hidden = YES;
        _numberImageView.hidden = YES;
        _selectButton.hidden = YES;
        _originalPhotoButton.hidden = YES;
        _originalPhotoLabel.hidden = YES;
        _doneButton.hidden = YES;
    }
}

- (void)showPhotoBytes {
    [[LFAssetManager manager] getPhotosBytesWithArray:@[_models[_currentIndex]] completion:^(NSString *totalBytes) {
        _originalPhotoLabel.text = [NSString stringWithFormat:@"(%@)",totalBytes];
    }];
}

#pragma mark - 编辑模式

#pragma mark 懒加载
- (UIView *)edit_naviBar
{
    if (_edit_naviBar == nil) {
        LFImagePickerController *imagePickerVc = (LFImagePickerController *)self.navigationController;
        
        _edit_naviBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.width, 64)];
        _edit_naviBar.backgroundColor = [UIColor colorWithRed:(34/255.0) green:(34/255.0)  blue:(34/255.0) alpha:0.7];
        
        UIButton *_edit_cancelButton = [[UIButton alloc] initWithFrame:CGRectMake(10, 10, 44, 44)];
        [_edit_cancelButton setTitle:@"取消" forState:UIControlStateNormal];
        _edit_cancelButton.titleLabel.font = [UIFont systemFontOfSize:15];
        [_edit_cancelButton setTitleColor:[UIColor colorWithWhite:0.8f alpha:1.f] forState:UIControlStateNormal];
        [_edit_cancelButton addTarget:self action:@selector(cancelButtonClick) forControlEvents:UIControlEventTouchUpInside];

        UIButton *_edit_finishButton = [[UIButton alloc] initWithFrame:CGRectMake(self.view.width - 54, 10, 44, 44)];
        [_edit_finishButton setTitle:@"完成" forState:UIControlStateNormal];
        _edit_finishButton.titleLabel.font = [UIFont systemFontOfSize:15];
        [_edit_finishButton setTitleColor:imagePickerVc.oKButtonTitleColorNormal forState:UIControlStateNormal];
        [_edit_finishButton addTarget:self action:@selector(finishButtonClick) forControlEvents:UIControlEventTouchUpInside];
        [_edit_naviBar addSubview:_edit_finishButton];
        [_edit_naviBar addSubview:_edit_cancelButton];
    }
    return _edit_naviBar;
}

- (UIView *)edit_toolBar
{
    if (_edit_toolBar == nil) {
        
        _edit_toolBar = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.height - 44, self.view.width, 44)];
        static CGFloat rgb = 34 / 255.0;
        _edit_toolBar.backgroundColor = [UIColor colorWithRed:rgb green:rgb blue:rgb alpha:0.7];
        
        NSInteger buttonCount = 5;
        
        CGFloat width = CGRectGetWidth(_edit_toolBar.frame)/buttonCount;
        
        for (NSInteger i=0; i<buttonCount; i++) {
            UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
            button.tag = i;
            button.frame = CGRectMake(width*i, 0, width, 44);
            button.titleLabel.font = [UIFont systemFontOfSize:14];
//            [button setImage:<#(nullable UIImage *)#> forState:UIControlStateNormal];
            [button setTitle:[NSString stringWithFormat:@"%zd", i] forState:UIControlStateNormal];
            [button addTarget:self action:@selector(edit_toolBar_buttonClick:) forControlEvents:UIControlEventTouchUpInside];
            [_edit_toolBar addSubview:button];
        }
    }
    return _edit_toolBar;
}



- (void)cancelButtonClick
{
    [self.edit_naviBar removeFromSuperview];
    [self.view addSubview:_naviBar];
    
    [self.edit_toolBar removeFromSuperview];
    [self.view addSubview:_toolBar];
}

- (void)finishButtonClick
{
    LFImagePickerController *imagePickerVc = (LFImagePickerController *)self.navigationController;
    [imagePickerVc showProgressHUD];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        [imagePickerVc hideProgressHUD];
        [self cancelButtonClick];
    });
}

- (void)edit_toolBar_buttonClick:(UIButton *)button
{
    switch (button.tag) {
        case LFEditPhotoType_draw:
            break;
        case LFEditPhotoType_sticker:
            break;
        case LFEditPhotoType_text:
            break;
        case LFEditPhotoType_splash:
            break;
        case LFEditPhotoType_crop:
            break;
    }
}
@end
