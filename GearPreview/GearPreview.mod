<?xml version="1.0" encoding="UTF-8"?>
<ModuleFile xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <UiMod name="GearPreview" version="@project-version@" date="@project-date@" autoenabled="true">
        <VersionSettings gameVersion="1.4.8" windowsVersion="1.0" savedVariablesVersion="1.0" />
        <Author name="Wholdar" email="" />
        <Description text="Adds a scryTome Gear Preview button to the character window. It builds a link to the scryTome Gear Preview with your worn items, dyes and appearance overrides." />
        <WARInfo>
            <Categories>
                <Category name="UTILITY" />
            </Categories>
        </WARInfo>
        <Dependencies>
            <Dependency name="EA_CharacterWindow" />
            <Dependency name="EA_ChatWindow" optional="true" />
            <Dependency name="LibSlash" optional="true" />
        </Dependencies>
        <Files>
            <File name="GearPreview.lua" />
            <File name="GearPreview.xml" />
        </Files>
        <OnInitialize>
            <CallFunction name="GearPreview.Initialize" />
        </OnInitialize>
    </UiMod>
</ModuleFile>
